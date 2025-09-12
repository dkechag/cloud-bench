#!/bin/bash
echo
echo "Running cloud bench..."
echo

/root/bench.pl -g

echo
echo "Results in /root/bench.csv"
echo "You can rerun with /root/bench.pl"


exec "$@"
