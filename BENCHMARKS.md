❯ MIX_ENV=bench LIMIT=1 SCALE=5000 RANGE=10000 PARALLEL=500 mix run bench/base.exs
parallel: 500
limit: 1
scale: 5000
range: 10000

Operating System: macOS
CPU Information: Apple M1 Max
Number of Available Cores: 10
Available memory: 32 GB
Elixir 1.17.3
Erlang 27.1.2
JIT enabled: true

Benchmark suite executing with the following configuration:
warmup: 14 s
time: 6 s
memory time: 0 ns
reduction time: 0 ns
parallel: 500
inputs: none specified
Estimated total run time: 1 min

Benchmarking hammer_mnesia_fix_window ...
Benchmarking hammer_mnesia_leaky_bucket ...
Benchmarking hammer_mnesia_token_bucket ...
Calculating statistics...
Formatting results...

Name                                 ips        average  deviation         median         99th %
hammer_mnesia_fix_window          706.71        1.42 ms   ±666.73%      0.0430 ms       65.51 ms
hammer_mnesia_leaky_bucket        269.06        3.72 ms    ±48.42%        3.46 ms        8.91 ms
hammer_mnesia_token_bucket        253.04        3.95 ms    ±67.17%        3.55 ms        9.39 ms

Comparison:
hammer_mnesia_fix_window          706.71
hammer_mnesia_leaky_bucket        269.06 - 2.63x slower +2.30 ms
hammer_mnesia_token_bucket        253.04 - 2.79x slower +2.54 ms

Extended statistics:

Name                               minimum        maximum    sample size                     mode
hammer_mnesia_fix_window        0.00058 ms      144.88 ms         1.59 M                0.0381 ms
hammer_mnesia_leaky_bucket       0.0639 ms       53.69 ms       807.25 K                  3.39 ms
hammer_mnesia_token_bucket         2.00 ms      125.49 ms       759.27 K                  3.41 ms
