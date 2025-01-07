# MIX_ENV=bench LIMIT=1 SCALE=5000 RANGE=10000 PARALLEL=500 mix run bench/base.exs
# inspired from https://github.com/PragTob/rate_limit/blob/master/bench/basic.exs
profile? = !!System.get_env("PROFILE")
parallel = String.to_integer(System.get_env("PARALLEL", "1"))
limit = String.to_integer(System.get_env("LIMIT", "1000000"))
scale = String.to_integer(System.get_env("SCALE", "60000"))
range = String.to_integer(System.get_env("RANGE", "1_000"))

IO.puts("""
parallel: #{parallel}
limit: #{limit}
scale: #{scale}
range: #{range}
""")

# TODO: clean up ETS table before/after each scenario
defmodule MnesiaFixWindowRateLimiter do
  use Hammer, backend: Hammer.Mnesia, algorithm: :fix_window
end

defmodule MnesiaLeakyBucketRateLimiter do
  use Hammer, backend: Hammer.Mnesia, algorithm: :leaky_bucket
end

defmodule MnesiaTokenBucketRateLimiter do
  use Hammer, backend: Hammer.Mnesia, algorithm: :token_bucket
end

MnesiaFixWindowRateLimiter.start_link([clean_period: :timer.minutes(60)])
MnesiaLeakyBucketRateLimiter.start_link([clean_period: :timer.minutes(60)])
MnesiaTokenBucketRateLimiter.start_link([clean_period: :timer.minutes(60)])

Benchee.run(
  %{
    "hammer_mnesia_fix_window" => fn key -> MnesiaFixWindowRateLimiter.hit("sites:#{key}", scale, limit) end,
    "hammer_mnesia_leaky_bucket" => fn key -> MnesiaLeakyBucketRateLimiter.hit("sites:#{key}", scale, limit) end,
    "hammer_mnesia_token_bucket" => fn key -> MnesiaTokenBucketRateLimiter.hit("sites:#{key}", scale, limit) end,
  },
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}],
  before_each: fn _ -> :rand.uniform(range) end,
  print: [fast_warning: false],
  time: 6,
  # fill the table with some data
  warmup: 14,
  profile_after: profile?,
  parallel: parallel
)
