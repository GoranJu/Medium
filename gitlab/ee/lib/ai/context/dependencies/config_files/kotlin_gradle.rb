# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        ### Example format:
        #
        # dependencies {
        #     // Format <group>:<name>:<version>
        #     implementation("org.codehaus.groovy:groovy:3.+")
        #     testImplementation("com.google.guava:guava:29.0.1") // Inline comment
        #
        #     // Project, file, or other dependencies are ignored
        #     implementation(project(":utils"))
        #     runtimeOnly(files("libs/a.jar", "libs/b.jar"))
        #
        #     // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/481317
        #     // String interpolation is not currently supported; below outputs nil as version
        #     implementation("com.esri.arcgisruntime:arcgis-java:$arcgisVersion")
        # }
        #
        class KotlinGradle < JavaGradle
          PREFIX_REGEX = /^(implementation|testImplementation)\(/ # Appears before each dependency

          def self.file_name_glob
            'build.gradle.kts'
          end

          def self.lang_name
            'Kotlin'
          end
        end
      end
    end
  end
end
