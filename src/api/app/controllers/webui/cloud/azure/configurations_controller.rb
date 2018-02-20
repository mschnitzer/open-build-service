module Webui
  module Cloud
    module Azure
      class ConfigurationsController < WebuiController
        before_action :require_login
        before_action :set_breadcrumb
        before_action -> { feature_active?(:cloud_upload) }

        def show
          @crumb_list << 'Microsoft Azure'
          @azure_configuration = User.current.azure_configuration || User.current.create_azure_configuration
          @configuration_available = @azure_configuration.subscription_id && @azure_configuration.management_certificate
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
            WebuiController.helpers.link_to('Configuration', configuration_cloud_path)
          ]
        end

        def permitted_params
          permitted_params = params.require(:cloud_azure_configuration).permit(:subscription_id, :management_certificate)

          if permitted_params[:management_certificate].is_a?(ActionDispatch::Http::UploadedFile)
            permitted_params[:management_certificate] = permitted_params[:management_certificate].read
          else
            # if it's not a file, the user manipulated the form, so we gonna ignore what they sent.
            permitted_params[:management_certificate] = nil
          end

          permitted_params
        end
      end
    end
  end
end
