#!/bin/bash
echo
echo "Running cloud bench..."
echo

/root/bench.pl -g

echo
echo "You can rerun with /root/bench.pl"
echo "(option -g to rerun Geekbench)"
echo

exec "$@"
