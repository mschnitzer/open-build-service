class CreateAzureConfiguration < ActiveRecord::Migration[5.1]
  def change
    create_table :cloud_azure_configurations, id: :integer do |t|
      t.belongs_to :user, index: true, type: :integer
      t.text :subscription_id, null: true, default: nil
      t.text :management_certificate, null: true, default: nil
      t.timestamps
    end
  end
end
