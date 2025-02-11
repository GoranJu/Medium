# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        class JavaGradle < Base
          START_SECTION_REGEX = /^dependencies {/ # Identifies the dependencies section
          END_SECTION_REGEX = /^}$/
          PREFIX_REGEX = /^['"]?(implementation|testImplementation)['"]?/ # Appears before each dependency
          LONG_FORM_NAME_REGEX = /name:\s*(?<value>[^,\s]*)/
          LONG_FORM_VERSION_REGEX = /version:\s*(?<value>[^,\s]*)/
          QUOTED_VALUE_REGEX = /(?<quote>["'])(?<value>[^"']+)\k<quote>/ # Matches value between double or single quotes
          INLINE_COMMENT_REGEX = %r{\s+//.*$}
          STRING_INTERPOLATION_CHAR = '$'
          EXCLUDE_KEYWORD = '('

          def self.file_name_glob
            'build.gradle'
          end

          def self.lang_name
            'Java'
          end

          private

          ### Example format:
          #
          # dependencies {
          #     // Short form: <group>:<name>:<version>
          #     implementation 'org.codehaus.groovy:groovy:3.+'
          #     testImplementation "com.google.guava:guava:29.0.1" // Inline comment
          #     // The quotes on `implementation` may be a legacy format; ported from Repository X-Ray Go repo
          #     "implementation" 'org.ow2.asm:asm:9.6'
          #
          #     // Long form
          #     implementation group: "org.neo4j", name: "neo4j-jmx", version: "1.3"
          #     testImplementation group: 'junit', name: 'junit', version: '4.11'
          #     "testImplementation" group: "org.apache.ant", name: "ant", version: "1.10.14"
          #
          #     // Project, file, or other dependencies are ignored
          #     implementation project(':utils')
          #     runtimeOnly files('libs/a.jar', 'libs/b.jar')
          #
          #     // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/481317
          #     // String interpolation is not currently supported; below outputs nil as version
          #     implementation "com.esri.arcgisruntime:arcgis-java:$arcgisVersion"
          # }
          #
          def extract_libs
            libs = []
            in_deps_section = false

            content.each_line do |line|
              line.strip!
              line.gsub!(INLINE_COMMENT_REGEX, '')

              if in_deps_section
                libs << parse_lib(line) if self.class::PREFIX_REGEX.match?(line)
                break if END_SECTION_REGEX.match?(line)
              elsif START_SECTION_REGEX.match?(line)
                in_deps_section = true
              end
            end

            libs.compact
          end

          def parse_lib(line)
            line.gsub!(self.class::PREFIX_REGEX, '')
            return if line.include?(EXCLUDE_KEYWORD)

            long_form_name_match = LONG_FORM_NAME_REGEX.match(line)

            if long_form_name_match
              # Parse long form (not used in Kotlin Gradle)
              name = long_form_name_match[:value].delete('"\'')
              version_match = LONG_FORM_VERSION_REGEX.match(line)
              version = version_match[:value].delete('"\'') if version_match
            else
              # Parse short form
              match = QUOTED_VALUE_REGEX.match(line)
              _group, name, version = match[:value].split(':') if match
            end

            name = nil if name&.include?(STRING_INTERPOLATION_CHAR)
            version = nil if version&.include?(STRING_INTERPOLATION_CHAR)

            Lib.new(name: name, version: version) if name
          end
        end
      end
    end
  end
end
