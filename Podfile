platform :ios, '9.0'

target 'MetalPetalGPUImageExtensionsDemo' do

  use_frameworks!

  pod 'MetalPetal', :git => 'https://github.com/MetalPetal/MetalPetal.git'

  pod 'GPUImage', :git => 'https://github.com/BradLarson/GPUImage.git', :commit => '167b0389bc6e9dc4bb0121550f91d8d5d6412c53'

  pod 'MetalPetalGPUImageExtensions', :path => 'Frameworks/MetalPetalGPUImageExtensions'

end

post_install do |installer|
    installer.pods_project.build_configurations.each do |config|
        config.build_settings['CLANG_WARN_UNGUARDED_AVAILABILITY'] = 'YES_AGGRESSIVE'
        config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'YES'
        config.build_settings['CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER'] = 'YES'
        config.build_settings['GCC_WARN_ABOUT_RETURN_TYPE'] = 'YES_ERROR'
        config.build_settings['GCC_WARN_ABOUT_MISSING_FIELD_INITIALIZERS'] = 'YES'
        config.build_settings['GCC_WARN_ABOUT_MISSING_PROTOTYPES'] = 'YES'
        config.build_settings['CLANG_WARN_ASSIGN_ENUM'] = 'YES'
        config.build_settings['GCC_WARN_SIGN_COMPARE'] = 'YES'
        config.build_settings['GCC_TREAT_INCOMPATIBLE_POINTER_TYPE_WARNINGS_AS_ERRORS'] = 'YES'
        config.build_settings['GCC_TREAT_IMPLICIT_FUNCTION_DECLARATIONS_AS_ERRORS'] = 'YES'
        config.build_settings['GCC_WARN_UNINITIALIZED_AUTOS'] = 'YES_AGGRESSIVE'
        config.build_settings['ENABLE_STRICT_OBJC_MSGSEND'] = 'YES'
        config.build_settings['GCC_NO_COMMON_BLOCKS'] = 'YES_AGGRESSIVE'
    end
end
