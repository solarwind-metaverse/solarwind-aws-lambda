#!/bin/sh

# env.sh

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
cat <<EOF
{
  "DB_SERVER": "$DB_SERVER",
  "DB_USER": "$DB_USER",
  "DB_PASSWORD": "$DB_PASSWORD"
}
EOF
