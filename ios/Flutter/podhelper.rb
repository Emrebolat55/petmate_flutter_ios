# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

require 'json'

# Hook for Podfile setup, installation settings.
def flutter_ios_podfile_setup; end
def flutter_macos_podfile_setup; end

def depends_on_flutter(target, engine_pod_name)
  target.dependencies.any? do |dependency|
    if dependency.name == engine_pod_name
      return true
    end
    if depends_on_flutter(dependency.target, engine_pod_name)
      return true
    end
  end
  return false
end

def flutter_additional_ios_build_settings(target)
  return unless target.platform_name == :ios
  inherit_deployment_target = target.deployment_target[/\d+/].to_i < 13
  force_to_arc_supported_min = target.deployment_target[/\d+/].to_i < 9

  # Dynamically find the artifacts dir based on FLUTTER_ROOT or relative paths
  flutter_root = ENV['FLUTTER_ROOT']
  if flutter_root && !flutter_root.empty?
    artifacts_dir = File.join(flutter_root, 'bin', 'cache', 'artifacts', 'engine')
  else
    artifacts_dir = File.expand_path(File.join('..', '..', '..', '..', 'bin', 'cache', 'artifacts', 'engine'), __FILE__)
  end
  
  debug_framework_dir = File.join(artifacts_dir, 'ios', 'Flutter.xcframework')
  release_framework_dir = File.join(artifacts_dir, 'ios-release', 'Flutter.xcframework')
  target_is_resource_bundle = target.respond_to?(:product_type) && target.product_type == 'com.apple.product-type.bundle'

  target.build_configurations.each do |build_configuration|
    build_configuration.build_settings['ONLY_ACTIVE_ARCH'] = 'NO' if build_configuration.type == :debug
    if target_is_resource_bundle
      build_configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      build_configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      build_configuration.build_settings['CODE_SIGNING_IDENTITY'] = '-'
      build_configuration.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = '-'
    end
    build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0' if force_to_arc_supported_min
    next unless depends_on_flutter(target, 'Flutter')
    build_configuration.build_settings['ENABLE_BITCODE'] = 'NO'
    configuration_engine_dir = build_configuration.type == :debug ? debug_framework_dir : release_framework_dir
    
    if Dir.exist?(configuration_engine_dir)
      Dir.new(configuration_engine_dir).each_child do |xcframework_file|
        next if xcframework_file.start_with?('.')
        if xcframework_file.end_with?('-simulator')
          build_configuration.build_settings['FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]'] = "\"#{configuration_engine_dir}/#{xcframework_file}\" $(inherited)"
        elsif xcframework_file.start_with?('ios-')
          build_configuration.build_settings['FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]'] = "\"#{configuration_engine_dir}/#{xcframework_file}\" $(inherited)"
        end
      end
    end
    
    build_configuration.build_settings['OTHER_LDFLAGS'] = '$(inherited) -framework Flutter'
    build_configuration.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    build_configuration.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET' if inherit_deployment_target
    build_configuration.build_settings['VALID_ARCHS[sdk=iphonesimulator*]'] = '$(ARCHS_STANDARD)'
    build_configuration.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = '$(inherited) i386'
    build_configuration.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = '$(inherited) armv7'
  end
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_engine_pod(ios_application_path)
  flutter_install_plugin_pods(ios_application_path, '.symlinks', 'ios')
end

def flutter_install_ios_engine_pod(ios_application_path = nil)
  ios_application_path ||= File.dirname(defined_in_file.realpath) if respond_to?(:defined_in_file)
  podspec_directory = File.join(ios_application_path, 'Flutter')
  pod 'Flutter', path: 'Flutter'
end

def flutter_install_plugin_pods(application_path = nil, relative_symlink_dir, platform)
  application_path ||= File.dirname(defined_in_file.realpath) if respond_to?(:defined_in_file)
  symlink_dir = File.expand_path(relative_symlink_dir, application_path)
  plugins_file = File.join(application_path, '..', '.flutter-plugins-dependencies')
  return unless File.exist?(plugins_file)
  
  dependencies_hash = JSON.parse(File.read(plugins_file))
  return unless dependencies_hash['plugins'] && dependencies_hash['plugins'][platform]
  
  dependencies_hash['plugins'][platform].each do |plugin_hash|
    plugin_name = plugin_hash['name']
    plugin_path = plugin_hash['path']
    next unless plugin_name && plugin_path
    
    # Simple relative pathing for CI stability
    pod plugin_name, :path => File.join('..', '.symlinks', 'plugins', plugin_name, 'ios')
  end
end
