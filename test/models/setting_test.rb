require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "validates presence of key" do
    setting = Setting.new(value: "test")
    assert_not setting.valid?
    assert_includes setting.errors[:key], "can't be blank"
  end

  test "validates uniqueness of key" do
    existing = settings(:api_key_setting)
    duplicate = Setting.new(key: existing.key, value: "different")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "get returns value for existing key" do
    setting = settings(:api_key_setting)
    assert_equal setting.value, Setting.get(setting.key)
  end

  test "get returns nil for non-existent key" do
    assert_nil Setting.get("non_existent_key")
  end

  test "set creates new setting" do
    assert_difference "Setting.count", 1 do
      Setting.set("new_key", "new_value")
    end
    assert_equal "new_value", Setting.get("new_key")
  end

  test "set updates existing setting" do
    setting = settings(:theme_setting)
    assert_no_difference "Setting.count" do
      Setting.set(setting.key, "light")
    end
    assert_equal "light", Setting.get(setting.key)
  end
end
