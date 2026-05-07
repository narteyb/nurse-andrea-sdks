module NurseAndrea
  class SlugValidator
    PATTERN = /\A[a-z][a-z0-9\-]{0,63}\z/

    HUMAN_READABLE_RULES =
      "Workspace slugs must be lowercase letters, numbers, or hyphens. " \
      "Must start with a letter. 1-64 characters."

    def self.valid?(slug)
      return false if slug.nil? || slug.to_s.empty?

      slug.to_s.match?(PATTERN)
    end
  end
end
