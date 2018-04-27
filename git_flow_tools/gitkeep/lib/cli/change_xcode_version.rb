# frozen_string_literal: true

# Class for changing the Xcode version
class ChangeXcodeVersion
  def xcode_proj_location
    '../../Register/Register.xcodeproj/project.pbxproj'
  end

  def change_xcode_version(text_utilities, logger, version)
    unless text_utilities.verify_text_matches_regex(/[1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/, version)
      logger.info 'Version did not match expected version regex'
      return false
    end
    if text_utilities.change_on_file(xcode_proj_location,
                                     /CURRENT_PROJECT_VERSION = [1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/,
                                     "CURRENT_PROJECT_VERSION = #{version}")
      logger.info "Xcode CURRENT_PROJECT_VERSION changed to #{version}"
      true
    else
      logger.info 'Unable to convert Register App version in the Xcode project file'
      false
    end
  end
end
