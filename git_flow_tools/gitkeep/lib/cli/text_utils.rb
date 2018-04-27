# frozen_string_literal: true

# Utitilies for changing text in the project.
class TextUtils
  def initialize(log)
    @logger = log
  end

  def verify_text_matches_regex(regex, str)
    regex =~ str
  end

  def find_text_in_file(file, regex_to_find)
    File.open file do |f|
      return f.find { |line| line =~ regex_to_find }
    end
  end

  def find_text_in_string(string_to_search, regex_to_find)
    string_to_search.match(regex_to_find).to_s
  end

  def change_on_file(file, regex_to_find, text_to_put_in_place)
    text = File.read file
    File.open(file, 'w+') do |f|
      f << text.gsub(regex_to_find,
                     text_to_put_in_place)
    end
  end
end

# Test version of utitilies for changing text in the project.
class TextUtilsTest
  def initialize(log)
    @logger = log
    @text_utilities = TextUtils.new(log)
  end

  def verify_text_matches_regex(regex, str)
    @text_utilities.verify_text_matches_regex(regex, str)
  end

  def find_text_in_file(file, regex_to_find)
    @text_utilities.find_text_in_file(file, regex_to_find)
  end

  def find_text_in_string(string_to_search, regex_to_find)
    @text_utilities.find_text_in_string(string_to_search, regex_to_find)
  end

  def change_on_file(_file, regex_to_find, text_to_put_in_place)
    @logger.info "TEST_MODE CODE CALL:: #{regex_to_find}, #{text_to_put_in_place}"
    true
  end
end
