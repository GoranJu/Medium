# frozen_string_literal: true

module GitlabSubscriptions
  class DiscoverTrialComponent < BaseDiscoverComponent
    extend ::Gitlab::Utils::Override

    private

    override :trial_type
    def trial_type
      'ultimate'
    end

    override :trial_active?
    def trial_active?
      namespace.ultimate_trial_plan?
    end

    override :discover_card_collection
    def discover_card_collection
      [
        {
          header: s_('DuoProDiscover|Privacy-first AI'),
          body: s_(
            "DuoProDiscover|Maintain control over the data that's sent to an external large language model (LLM) " \
              "service. Your organization's proprietary data and code are never used to train external AI models."
          )
        },
        {
          header: s_('DuoProDiscover|Boost team collaboration'),
          body: s_(
            "DuoProDiscover|Streamline communication, facilitate knowledge sharing, and improve project management."
          )
        },
        {
          header: s_('DuoProDiscover|Improve developer experience'),
          body: s_(
            "DuoProDiscover|A single platform integrates the best AI model for each use case across the entire " \
              "development workflow."
          )
        },
        {
          header: s_('DuoProDiscover|Transparent AI'),
          body: safe_format(
            s_(
              "DuoProDiscover|The GitLab %{link_start}AI Transparency Center%{link_end} details how GitLab upholds " \
                "ethics and transparency in its AI-powered features."
            ),
            tag_pair(
              link_to(
                '', 'https://about.gitlab.com/ai-transparency-center/',
                data: {
                  testid: 'ai-transparency-link',
                  track_action: documentation_link_track_action,
                  track_label: 'ai_transparency_center_feature'
                },
                class: 'gl-contents',
                target: '_blank',
                rel: 'noopener noreferrer'
              ),
              :link_start,
              :link_end
            )
          )
        }
      ]
    end

    override :core_section_one_card_collection
    def core_section_one_card_collection
      [
        {
          header: s_('TrialsDiscover|Increase security'),
          body: s_(
            "TrialDiscover|End-to-end security and compliance, built right into the platform your developers " \
              "already use."
          ),
          footer: render_footer_link(
            link_text: s_('TrialDiscover|Security Dashboard - Advanced Security Testing'),
            link_path: 'https://www.youtube.com/watch?v=Uo-pDns1OpQ',
            track_label: 'end_to_end_security_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('TrialsDiscover|Improve collaboration'),
          body: s_(
            "TrialDiscover|Streamline communication to build, test, package, and deploy secure software in a " \
              "fraction of the time."
          ),
          footer: render_footer_link(
            link_text: s_('TrialDiscover|How to use GitLab for Agile software development'),
            link_path: 'https://about.gitlab.com/blog/2018/03/05/gitlab-for-agile-software-development/',
            track_label: 'collaboration_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('TrialsDiscover|Gain actionable insights'),
          body: s_(
            "TrialDiscover|Deliver value faster with metrics derived from a unified data store to increase revenue, " \
              "accelerate speed."
          ),
          footer: render_footer_link(
            link_text: s_('TrialDiscover|GitLab Value Streams Dashboard'),
            link_path: 'https://www.youtube.com/watch?v=8pLEucNUlWI',
            track_label: 'stream_insights_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('TrialsDiscover|Enhance productivity'),
          body: s_(
            "TrialDiscover|Reliable and feature rich automations help remove cognitive load and unnecessary " \
              "repetitive work."
          )
        }
      ]
    end

    override :core_section_two_card_collection
    def core_section_two_card_collection
      [
        {
          header: s_('DuoEnterpriseDiscover|Boost productivity with smart code assistance'),
          body: s_(
            "DuoEnterpriseDiscover|Write secure code faster with AI-powered suggestions in more than 20 languages, " \
              "and chat with your AI companion throughout development."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Code Suggestions'),
            link_path: 'https://www.youtube.com/watch?v=ds7SG1wgcVM',
            track_label: 'code_assistance_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoEnterpriseDiscover|Fortify your code'),
          body: s_(
            "DuoEnterpriseDiscover|AI-powered vulnerability explanation and resolution features to remediate " \
              "vulnerabilities and uplevel skills."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Vulnerability explanation'),
            link_path: 'https://www.youtube.com/watch?v=MMVFvGrmMzw',
            track_label: 'vulnerability_explanation_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoEnterpriseDiscover|Advanced troubleshooting'),
          body: s_(
            "DuoEnterpriseDiscover|AI-assisted root cause analysis for CI/CD job failures, and suggested " \
              "fixes to quickly remedy broken pipelines."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Root cause analysis'),
            link_path: 'https://www.youtube.com/watch?v=Sa0UBpMqXgs',
            track_label: 'root_cause_analysis_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoEnterpriseDiscover|Measure the ROI of AI'),
          body: s_(
            "DuoEnterpriseDiscover|Granular usage data, performance improvements, and productivity metrics to " \
              "evaluate the effectiveness of AI in software development."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|AI Impact Dashboard measures the ROI of AI'),
            link_path: 'https://about.gitlab.com/blog/2024/05/15/developing-gitlab-duo-ai-impact-analytics-dashboard-measures-the-roi-of-ai/',
            track_label: 'ai_impact_analytics_dashboard_feature',
            track_action: documentation_link_track_action
          )
        }
      ]
    end

    override :glm_content
    def glm_content
      'trial_discover_page'
    end

    override :text_page_title
    def text_page_title
      s_('TrialDiscover|Discover')
    end

    override :why_section_header_text
    def why_section_header_text
      s_('TrialDiscover|Why Ultimate & GitLab Duo Enterprise?')
    end

    override :core_feature_one_header_text
    def core_feature_one_header_text
      s_('TrialDiscover|One platform to empower Dev, Sec, and Ops teams')
    end

    override :core_feature_one_grid_class
    def core_feature_one_grid_class
      'md:gl-grid-cols-4'
    end

    override :core_feature_one_header_text
    def core_feature_two_header_text
      s_('TrialDiscover|Duo Enterprise')
    end

    override :core_feature_two_grid_class
    def core_feature_two_grid_class
      'md:gl-grid-cols-4'
    end

    override :hero_logo
    def hero_logo
      'duo_pro/logo.svg'
    end

    override :hero_header_text
    def hero_header_text
      s_(
        'TrialDiscover|Ship software faster and more securely with AI integrated into your entire DevSecOps lifecycle.'
      )
    end

    override :buy_now_link
    def buy_now_link; end

    override :hero_video
    def hero_video
      'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479'
    end

    override :hero_thumbnail
    def hero_thumbnail
      'duo_pro/video-thumbnail.png'
    end
  end
end
