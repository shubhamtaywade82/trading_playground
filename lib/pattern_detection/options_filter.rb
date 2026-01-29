# frozen_string_literal: true

# Options-specific filters: IV percentile, ATM±1 only, time to expiry.
# OPTION_FILTER: IV < IV_percentile_70, ATM or ATM±1 only, time_to_expiry >= 2 days.
module PatternDetection
  class OptionsFilter
    IV_PERCENTILE_MAX = 70
    MIN_DAYS_TO_EXPIRY = 2
    STRIKE_OFFSET_MAX = 1 # ATM±1

    def initialize(iv_percentile: nil, days_to_expiry: nil, strike_offset: nil)
      @iv_percentile = iv_percentile
      @days_to_expiry = days_to_expiry
      @strike_offset = strike_offset
    end

    # Returns { passed: true/false, reason: string }
    def run
      iv_ok = @iv_percentile.nil? || @iv_percentile < IV_PERCENTILE_MAX
      expiry_ok = @days_to_expiry.nil? || @days_to_expiry >= MIN_DAYS_TO_EXPIRY
      strike_ok = @strike_offset.nil? || @strike_offset.abs <= STRIKE_OFFSET_MAX

      passed = iv_ok && expiry_ok && strike_ok
      reasons = []
      reasons << "IV percentile #{@iv_percentile} >= #{IV_PERCENTILE_MAX}" unless iv_ok
      reasons << "Days to expiry #{@days_to_expiry} < #{MIN_DAYS_TO_EXPIRY}" unless expiry_ok
      reasons << "Strike offset #{@strike_offset} beyond ATM±#{STRIKE_OFFSET_MAX}" unless strike_ok

      { passed: passed, reason: reasons.empty? ? 'OK' : reasons.join('; ') }
    end
  end
end
