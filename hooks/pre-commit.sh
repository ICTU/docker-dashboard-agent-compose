#!/bin/sh

npm test > /dev/null 2>&1
RESULT=$?

if [ $RESULT -ne 0 ]; then
  echo ""
  echo "There are test failures, aborting commit.."
  echo "Please exucute tests with: npm test"
  echo ""
  exit 1
else
  exit 0
fi
