# frozen_string_literal: true

# Strike selection: ATM or ATM±1. Extend with option chain + OI when wired.
class StrikeSelector
  def self.atm_or_offset(spot, offset: 0)
    spot.round(-2) + (offset * 100)  # NIFTY-style; adjust for index
  end
end
