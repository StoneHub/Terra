# frozen_string_literal: true

require_relative "test_helper"

class MentorTest < Minitest::Test
  include TerraTest

  # Godhood.mentor is module-level state like Godhood.world — reset it so
  # a hush! in one test can't silence the ones after it.
  def teardown
    Terra::Godhood.mentor = nil
  end

  def test_a_successful_act_prints_the_live_signature_and_an_example
    out, = capture_io { god.let_there_be :light }
    assert_match(/✍️ {2}let_there_be what/, out)
    assert_match(/↳ try: let_there_be/, out)
  end

  def test_the_signature_is_read_off_the_method_not_hardcoded
    lit_world!
    out, = capture_io { god.spawn :lake }
    # req + every kwarg + the block slot, in declaration order.
    assert_match(/✍️ {2}spawn kind, at:, size:, name:, count:, length:, width:, &brain/, out)
  end

  def test_a_refused_act_teaches_nothing
    out, = capture_io { god.spawn :lake } # no light yet — refused
    refute_match(/✍️/, out)
  end

  def test_pass_gets_a_mentor_note_too
    lit_world!
    out, = capture_io { god.pass 3 }
    assert_match(/✍️ {2}pass days = …/, out)
  end

  def test_hush_silences_and_mentor_restores
    lit_world!
    quietly { god.hush! }
    out, = capture_io { god.spawn :lake }
    refute_match(/✍️/, out)

    quietly { god.mentor! }
    out, = capture_io { god.spawn :forest }
    assert_match(/✍️ {2}spawn/, out)
  end

  def test_every_example_key_is_a_real_power_and_examples_lead_with_it
    Terra::Lore::EXAMPLES.each do |power, examples|
      assert god.respond_to?(power), "EXAMPLES lists unknown power #{power.inspect}"
      examples.each do |line|
        assert_match(/\A#{power}[ (]/, line, "example for #{power.inspect} should start with it: #{line}")
      end
    end
  end
end
