class MaintenanceIncidentsController < ApplicationController
  skip_before_action :extract_user

  def show
    @project = MaintenanceIncident.find_by(incident_id: params[:id]).project
    @request = BsRequest.
        joins(:bs_request_actions).
        find_by(bs_request_actions: { source_project: @project.name, type: 'maintenance_release' })

    @issues = @project.issues
  end
end
