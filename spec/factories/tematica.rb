# coding: UTF-8

FactoryGirl.define do
  factory :tematica do
    nombre        { Faker::Lorem.word }
  end
end
