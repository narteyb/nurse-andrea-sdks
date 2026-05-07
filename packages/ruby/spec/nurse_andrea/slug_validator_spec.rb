require "spec_helper"

RSpec.describe NurseAndrea::SlugValidator do
  describe ".valid?" do
    it "accepts a single-letter slug" do
      expect(described_class.valid?("a")).to be true
    end

    it "accepts a normal lowercase slug with hyphens and digits" do
      expect(described_class.valid?("checkout-2")).to be true
      expect(described_class.valid?("a1-b2-c3")).to be true
    end

    it "accepts a 64-character slug" do
      slug = "a" + ("b" * 63)
      expect(slug.length).to eq(64)
      expect(described_class.valid?(slug)).to be true
    end

    it "rejects nil and empty strings" do
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?("")).to be false
    end

    it "rejects slugs starting with a digit" do
      expect(described_class.valid?("1-checkout")).to be false
    end

    it "rejects slugs starting with a hyphen" do
      expect(described_class.valid?("-checkout")).to be false
    end

    it "rejects uppercase letters" do
      expect(described_class.valid?("Checkout")).to be false
      expect(described_class.valid?("CHECKOUT")).to be false
    end

    it "rejects underscores and other punctuation" do
      expect(described_class.valid?("check_out")).to be false
      expect(described_class.valid?("check.out")).to be false
      expect(described_class.valid?("check out")).to be false
    end

    it "rejects slugs longer than 64 chars" do
      slug = "a" + ("b" * 64)
      expect(slug.length).to eq(65)
      expect(described_class.valid?(slug)).to be false
    end
  end
end
