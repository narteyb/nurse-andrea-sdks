require "rails/generators"

module NurseAndrea
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Creates a NurseAndrea initializer and configures your app"

      def create_initializer
        template "nurse_andrea.rb.tt", "config/initializers/nurse_andrea.rb"
      end

      def mount_engine
        route 'mount NurseAndrea::Engine => "/nurse_andrea"'
      end

      def add_gitignore_entry
        append_to_file ".gitignore", "\n# NurseAndrea backfill marker\n.nurse_andrea_backfill_done\n"
      end

      def show_next_steps
        say "\nNurseAndrea installed!", :green
        say "Next steps:", :bold
        say "  1. Set NURSE_ANDREA_TOKEN in your environment (.env or hosting platform)"
        say "  2. Set NURSE_ANDREA_HOST (default: https://nurseandrea.io)"
        say "     For local dev: http://localhost:4500"
        say "     For staging:   https://staging.nurseandrea.io"
        say "  3. Get your token from: https://nurseandrea.io/dashboard/settings"
        say "  4. Start your app — NurseAndrea will auto-connect and backfill\n"
      end
    end
  end
end
