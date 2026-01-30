# frozen_string_literal: true

# Loads intraday-options skill pack from .cursor/skills and builds guardrails text
# for AI prompts. Single responsibility: read SKILL.md files and emit a single block.
module IntradayOptionsSkills
  SKILL_NAMES = %w[
    market-regime
    strike-selection
    entry-validation
    risk-sizing
    execution-safety
    exit-management
    post-trade-intel
  ].freeze

  class << self
    # Returns a string to append to the system prompt: Hard Rules + output expectations
    # so the model follows the same guardrails. root: base path to repo (default: parent of lib/).
    def guardrails_for_prompt(root: nil)
      base = root || File.expand_path('..', __dir__)
      skills_dir = File.join(base, '.cursor', 'skills', 'intraday-options')
      return '' unless File.directory?(skills_dir)

      parts = []
      SKILL_NAMES.each do |name|
        path = File.join(skills_dir, name, 'SKILL.md')
        next unless File.file?(path)

        body = extract_guardrails(File.read(path))
        parts << body if body && !body.strip.empty?
      end
      return '' if parts.empty?

      [
        '---',
        'Intraday-options guardrails (apply in order; if any rejects, no trade):',
        parts.join("\n\n"),
        '---'
      ].join("\n")
    end

    private

    def extract_guardrails(raw)
      content = strip_frontmatter(raw)
      return nil if content.strip.empty?

      # Take "## Hard Rules" and optionally "## Output" so the model sees constraints and shape.
      blocks = []
      if (rules = section(content, 'Hard Rules'))
        blocks << "Hard Rules:\n#{rules.strip}"
      end
      if (out = section(content, 'Output'))
        blocks << "Output (follow this shape when relevant):\n#{out.strip}"
      end
      title_line = content.lines.find { |l| l.match?(/^#+\s+\S/) }
      title = title_line.to_s.sub(/\A#+\s*/, '').strip
      return nil if blocks.empty?

      label = title.empty? ? nil : "[#{title}]"
      [label, blocks.join("\n\n")].compact.join("\n")
    end

    def strip_frontmatter(raw)
      s = raw.strip
      return s unless s.start_with?('---')

      idx = s.index("\n---", 3)
      idx ? s[(idx + 4)..].to_s : s
    end

    def section(content, heading)
      # Match "## Heading" or "## Heading (optional)"
      regex = /\n##\s+#{Regexp.escape(heading)}\s*(?:\([^)]*\))?\s*\n(.*?)(?=\n##\s|\z)/m
      content.match(regex)&.captures&.first
    end
  end
end
