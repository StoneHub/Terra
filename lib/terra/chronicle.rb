# frozen_string_literal: true

require "erb"

module Terra
  # Writes a world's history to a standalone HTML page — the same trick
  # Rails views use: an ERB template with Ruby woven into the markup,
  # rendered against a binding that can see `world`.
  module Chronicle
    TEMPLATE = File.join(__dir__, "chronicle.html.erb")

    def self.write(world, path: "terra-chronicle.html")
      # Read as UTF-8 explicitly — under a C/POSIX locale File.read hands
      # back BINARY, and interpolating emoji into that raises
      # Encoding::CompatibilityError deep inside ERB#result.
      template = ERB.new(File.read(TEMPLATE, encoding: "UTF-8"), trim_mode: "-")
      File.write(path, template.result(binding), encoding: "UTF-8")
      path
    end

    # ERB has no HTML auto-escaping outside Rails; h is convention.
    def self.h(text) = ERB::Util.html_escape(text)
  end
end
