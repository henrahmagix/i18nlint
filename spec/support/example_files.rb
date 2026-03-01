# frozen_string_literal: true

require "pp"

module ExampleFiles
  DIR = Pathname.new File.expand_path("../example", __dir__)

  at_exit { reset }

  def self.setup = reset

  def self.reset
    @n = 0
    FileUtils.rm_r DIR
  rescue Errno::ENOENT
    # pass
  ensure
    FileUtils.mkdir DIR
  end

  def temp_file(filepath, content)
    filepath = Pathname.new File.join(DIR, filepath)
    begin; FileUtils.mkdir_p(filepath.dirname); rescue Errno::EEXIST; nil; end
    File.write(filepath, content)
    filepath.to_s
  end

  CHARS_KEY = ("a".."z").to_a + ["_"]
  CHARS_TEXT = [("a".."z"), ("A".."Z"), ("0".."9"), [" "], %w[- _ . ! ? & : ; < = > @ ^ +]].map(&:to_a).flatten

  def random_files(num = nil, locales_per: nil, segments_per: nil)
    if num
      yaml_num = rand_n1(num)
      ruby_num = num - yaml_num
    end
    yaml_files = random_yaml_files(yaml_num, locales_per:, segments_per:)
    yaml_files + random_ruby_files(ruby_num, locales_per:, segments_per:)
  end

  def random_yaml_files(num = nil, locales_per: nil, segments_per: nil)
    _random_files "file_%d.yml", num, locales_per, segments_per, &:to_yaml
  end

  def random_json_files(num = nil, locales_per: nil, segments_per: nil)
    _random_files "file_%d.json", num, locales_per, segments_per, &:to_json
  end

  def random_ruby_files(num = nil, locales_per: nil, segments_per: nil)
    _random_files "file_%d.rb", num, locales_per, segments_per, &:pretty_inspect
  end

  private

  def _random_files(name, num_files, locales_per, segments_per)
    n_to_avoid_overwriting = ExampleFiles.instance_variable_set :@n, ExampleFiles.instance_variable_get(:@n) + 1
    name = suffix_filename(name, n_to_avoid_overwriting)
    (num_files ? num_files.times : rand_times(20)).map do |n|
      content = yield rand_hash(locales_per || 1, segments_per || rand_n1(50))
      temp_file name % n, content
    end
  end

  def suffix_filename(filepath, suffix)
    filepath = Pathname.new(filepath)
    filepath = filepath.sub_ext "#{suffix}#{filepath.extname}"
    filepath.to_s
  end

  def rand_times(num, &)
    num ||= 0
    num = rand(num) if num > 1

    (num + 1).times(&)
  end

  def rand_n1(num)
    return 1 if num == 0

    rand(num) + 1
  end

  def rand_s(set, num) = rand_times(num).map { set[rand(set.length)] }.join

  def rand_hash(num_locales, num_segments = num_locales)
    {}.tap do |h|
      num_locales.times do
        h[rand_s(CHARS_KEY, 2)] = num_segments.times.to_h { [rand_s(CHARS_KEY, 50), rand_s(CHARS_TEXT, 50)] }
      end
    end
  end
end
