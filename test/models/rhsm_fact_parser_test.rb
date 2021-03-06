require 'katello_test_helper'

module Katello
  class RhsmFactParserTest < ActiveSupport::TestCase
    def setup
      @facts = {
        'net.interface.eth0.mac_address' => '00:00:00:00:00:12',
        'net.interface.eth0.ipv4_address' => '192.168.0.1',
        'net.interface.eth0.1.mac_address' => '00:00:00:00:00:12',
        'net.interface.eth0.1.ipv4_address' => '192.168.0.2',
        'net.interface.ethnone.mac_address' => 'none',
        'net.interface.eth2.mac_address' => '00:00:00:00:00:13',
        'net.interface.eth3.ipv4_address' => 'Unknown',
        'net.interface.eth3.mac_address' => '00:00:00:00:00:14'
      }
    end
    let(:parser) { RhsmFactParser.new(@facts) }

    def test_virtual_interfaces
      assert parser.interfaces['eth0.1'][:virtual]
      refute parser.interfaces['eth0'][:virtual]
    end

    def test_get_interfaces
      interfaces = parser.get_interfaces
      assert_includes interfaces, 'eth0'
      refute_includes interfaces, 'ethnone'
      assert_includes interfaces, 'eth2'
    end

    def test_get_facts_for_interface_with_ip
      expected_eth0 = {
        'link' => true,
        'macaddress' => @facts['net.interface.eth0.mac_address'],
        'ipaddress' => @facts['net.interface.eth0.ipv4_address']
      }
      assert_equal expected_eth0, parser.get_facts_for_interface('eth0')
    end

    def test_get_facts_for_interface_without_ip
      expected_eth1 = {
        'link' => true,
        'macaddress' => @facts['net.interface.eth1.mac_address'],
        'ipaddress' => nil
      }
      assert_equal expected_eth1, parser.get_facts_for_interface('eth1')
    end

    def test_get_facts_for_interface_with_invalid_ip
      assert_equal @facts['net.interface.eth3.mac_address'], parser.get_facts_for_interface('eth3')['macaddress']
      assert_empty parser.get_facts_for_interface('eth3')['ipaddress']
    end

    def test_valid_centos_os
      @facts['distribution.name'] = 'CentOS'
      @facts['distribution.version'] = '7.2'

      assert parser.operatingsystem.is_a?(::Operatingsystem)
    end

    def test_invalid_centos_os
      @facts['distribution.name'] = 'CentOS'
      @facts['distribution.version'] = '7'

      refute parser.operatingsystem
    end

    def test_operatingsystem_debian
      @facts['distribution.name'] = 'Debian GNU/Linux'
      @facts['distribution.version'] = '9'
      @facts['distribution.id'] = 'stretch'

      assert_equal parser.operatingsystem.release_name, 'stretch'
      assert_equal parser.operatingsystem.name, 'Debian'
      assert_equal parser.operatingsystem.type, 'Debian'
    end

    def test_operatingsystem_ubuntu
      @facts['distribution.name'] = 'Ubuntu GNU/Linux'
      @facts['distribution.version'] = '19'
      @facts['distribution.id'] = 'disco'

      assert_equal parser.operatingsystem.release_name, 'disco'
      assert_equal parser.operatingsystem.name, 'Ubuntu'
      assert_equal parser.operatingsystem.type, 'Debian'
    end

    def test_uname_architecture
      @facts['uname.machine'] = 'i686'

      assert 'i386', parser.architecture.name
    end
  end
end
