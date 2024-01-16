#!/bin/bash

# Run spyglass
echo "Running spyglass. This will take a while..."
sg_shell -enable_pass_exit_codes < ./scripts/lint_spyglass.tcl

SPYGLASS_RETURN_CODE=$?

# Show reports
cat spyglass_reports/top_tile/lint/lint_rtl/spyglass_reports/moresimple.rpt

# Show summary
echo "*** Spyglass Lint Summary ***"
cat spyglass_reports/Run_Summary/*.txt

exit $SPYGLASS_RETURN_CODE