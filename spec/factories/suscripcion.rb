# coding: UTF-8

FactoryGirl.define do
  factory :suscripcion do
    nombre_apellidos  { "#{Faker::Name.first_name} #{Faker::Name.last_name}" }
    email             { Faker::Internet.email }
  end
end
