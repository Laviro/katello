#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

class UsersController < ApplicationController
  include AutoCompleteSearch
  
  def section_id
     'operations'
  end
   
  before_filter :setup_options, :only => [:items, :index]
  before_filter :find_user, :only => [:edit, :update, :update_roles, :clear_helptips, :destroy]
  before_filter :authorize
  skip_before_filter :require_org

  def rules
    index_test = lambda{User.any_readable?}
    create_test = lambda{User.creatable?}

    read_test = lambda{@user.readable?}
    edit_test = lambda{@user.editable?}
    delete_test = lambda{@user.deletable?}
    edit_details_test = lambda{@user.id == current_user.id || @user.editable?}
    user_helptip = lambda{true} #everyone can enable disable a helptip
    
     {
       :index => index_test,
       :items => index_test,
       :auto_complete_search => index_test,
       :new => create_test,
       :create => create_test,
       :edit => read_test,
       :update => edit_details_test,
       :update_roles => edit_test,
       :clear_helptips => edit_details_test,
       :destroy => delete_test,
       :enable_helptip => user_helptip,
       :disable_helptip => user_helptip,
     }
  end
  
  def items
    render_panel_items(User.readable, @panel_options, params[:search], params[:offset])
  end

  
  def edit 
    render :partial=>"edit", :layout => "tupane_layout", :locals=>{:user=>@user, :editable=>@user.editable?, :name=>controller_display_name}
  end
  
  def new
    @user = User.new
    render :partial=>"new", :layout => "tupane_layout", :locals=>{:user=>@user}
  end

  def create
    @user = User.new(params[:user])
    @user.save!
    notice @user.username + _(" created successfully.")
   
    if User.where(:id => @user.id).search_for(params[:search]).include?(@user) 
      render :partial=>"common/list_item", :locals=>{:item=>@user, :accessor=>"id", :columns=>["username"], :name=>controller_display_name}
    else
      notice _("'#{@user["name"]}' did not meet the current search criteria and is not being shown."), { :level => 'message', :synchronous_request => false }
      render :json => { :no_match => true }
    end
  rescue Exception => error
    errors error
    render :json=>@user.errors, :status=>:bad_request
  end
  
  def update
    params[:user].delete :username

    if @user.update_attributes(params[:user])
      notice _("User updated successfully.")
      attr = params[:user].first.last if params[:user].first
      attr ||= ""
      
      if not User.where(:id => @user.id).search_for(params[:search]).include?(@user)
        notice _("'#{@user["name"]}' no longer matches the current search criteria."), { :level => 'message', :synchronous_request => false }
      end
      
      render :text => attr and return
    end
    errors "", {:list_items => @user.errors.to_a}
    render :text => @user.errors, :status=>:ok
  end

  def update_roles
    params[:user] = {"role_ids"=>[]} unless params.has_key? :user

    #Add in the own role if updating roles, cause the user shouldn't see his own role
    params[:user][:role_ids] << @user.own_role.id

    if  @user.update_attributes(params[:user])
      notice _("User updated successfully.")
      
      if not User.where(:id => @user.id).search_for(params[:search]).include?(@user)
        notice _("'#{@user["name"]}' no longer matches the current search criteria."), { :level => 'message', :synchronous_request => false }
      end
      
      render :nothing => true and return
    end
    errors "", {:list_items => @user.errors.to_a}
    render :text => @user.errors, :status=>:ok
  end

  def destroy
    @id = params[:id]
    begin
      #remove the user
      @user.destroy
      if @user.destroyed?
        notice _("User '#{@user[:username]}' was deleted.")
        #render and do the removal in one swoop!
        render :partial => "common/list_remove", :locals => {:id => @id, :name=>controller_display_name} and return
      end
      errors "", {:list_items => @user.errors.to_a}
      render :text => @user.errors, :status=>:ok
    rescue Exception => error
      errors error
      render :json=>@user.errors, :status=>:bad_request
    end
    errors "", {:list_items => @user.errors.to_a}
    render :text => @user.errors, :status=>:ok
  rescue Exception => error
    errors error
    render :json=>@user.errors, :status=>:bad_request
  end

  def clear_helptips
    @user.clear_helptips
    notice _("Disabled help tips have been re-enabled.")
    render :text => _("Cleared")
  end

  def enable_helptip
    current_user.enable_helptip params[:key]
    render :text => ""
  end

  def disable_helptip
    current_user.disable_helptip params[:key]
    render :text => ""
  end

  private

  def find_user
    @user = User.find params[:id]
  end
  

  def setup_options
    @panel_options = { :title => _('Users'),
                 :col => ['username'],
                 :create => _('User'),
                 :name => controller_display_name,
                 :ajax_load  => true,
                 :ajax_scroll => items_users_path(),
                 :enable_create => User.creatable? }
  end

  def controller_display_name
    return _('user')
  end

end
