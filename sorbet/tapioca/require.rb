# typed: false
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)

# Workaround for tapioca 0.19.0 vs sorbet-runtime 0.6.13153 mismatch.
# `has_rest` / `has_keyrest` were removed from T::Private::Methods::Signature
# but tapioca still calls them in sorbet_signatures.rb. Restore as thin aliases
# backed by the remaining nil-check on the rest name.
require "sorbet-runtime"
module T
  module Private
    module Methods
      class Signature
        def has_rest
          !rest_name.nil?
        end unless method_defined?(:has_rest)

        def has_keyrest
          !keyrest_name.nil?
        end unless method_defined?(:has_keyrest)
      end
    end
  end
end
