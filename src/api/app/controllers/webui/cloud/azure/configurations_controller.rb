module Webui
  module Cloud
    module Azure
      class ConfigurationsController < WebuiController
        before_action :require_login
        before_action :set_breadcrumb
        before_action -> { feature_active?(:cloud_upload) }

        def show
          @crumb_list << 'Azure Configuration'
          @azure_configuration = User.current.azure_configuration || User.current.create_azure_configuration
          @configuration_available = @azure_configuration.application_id && @azure_configuration.application_key
        end

        def update
          @azure_configuration = User.current.azure_configuration

          if @azure_configuration.update(permitted_params)
            flash[:success] = 'Successfully updated your Azure configuration.'
          else
            flash[:error] = "Could not update your Azure configuration: #{@azure_configuration.errors.full_messages.to_sentence}."
          end

          redirect_to cloud_azure_configuration_path
        end

        def destroy
          @azure_configuration = User.current.azure_configuration
          @azure_configuration.destroy! if @azure_configuration

          flash[:success] = "You've successfully deleted your Azure configuration."
          redirect_to cloud_azure_configuration_path
        end

        private

        def set_breadcrumb
          @crumb_list = [
            WebuiController.helpers.link_to('Cloud Upload', cloud_upload_index_path),
            WebuiController.helpers.link_to('Configuration', cloud_configuration_index_path)
          ]
        end

        def permitted_params
          params.require(:cloud_azure_configuration).permit(:application_id, :application_key)
        end
      end
    end
  end
end
