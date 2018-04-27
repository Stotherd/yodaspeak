# frozen_string_literal: true

# Class for changing the Xcode version
class XCodeUtils
  def xcode_proj_location
    '../../Register/Register.xcodeproj/project.pbxproj'
  end

  def get_xcode_version(text_utilities)
    str = text_utilities.find_text_in_file(xcode_proj_location, /CURRENT_PROJECT_VERSION = [1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/)
    text_utilities.find_text_in_string(str, /[1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/)
  end

  def increment_minor_xcode_version(text_utilities, _logger)
    xcode_version = get_xcode_version(text_utilities)
    major = text_utilities.find_text_in_string(xcode_version, /([0-9]?[0-9])\./).tr('.', '')
    minor = text_utilities.find_text_in_string(xcode_version, /\.([0-9]?[0-9])\./).tr('.', '').to_i
    "#{major}.#{(minor + 1)}.0"
  end

  def change_xcode_version(text_utilities, logger, version)
    unless text_utilities.verify_text_matches_regex(
      /[1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/,
      version
    )
      logger.info 'Version did not match expected version regex'
      return false
    end
    if text_utilities.change_on_file(
      xcode_proj_location,
      /CURRENT_PROJECT_VERSION = [1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/,
      "CURRENT_PROJECT_VERSION = #{version}"
    )
      logger.info "Xcode CURRENT_PROJECT_VERSION changed to #{version}"
      true
    else
      logger.info
      'Unable to convert Register App version in the Xcode project file'
      false
    end
  end
end
