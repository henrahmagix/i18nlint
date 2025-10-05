# frozen_string_literal: true

[
  "1.0.1",
  "1.1.1",
  "1.2.0",
  "1.3.0",
  "1.4.0",
  "1.5.3",
  "1.6.0",
  "1.7.1",
  "1.8.11",
  "1.9.1",
  "1.10.0",
  "1.11.0",
  "1.12.0",
  "1.13.0",
  "1.14.0"
].each do |v|
  appraise "i18n-#{v}" do
    gem "i18n", v
  end
end

appraise "i18n-v1-latest" do
  gem "i18n", "1.14.7"
end
