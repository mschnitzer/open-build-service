FactoryBot.define do
  factory :azure_configuration, class: Cloud::Azure::Configuration do
    user
    application_id { Faker::Lorem.characters }
    application_key { Faker::Lorem.characters }
  end
end
