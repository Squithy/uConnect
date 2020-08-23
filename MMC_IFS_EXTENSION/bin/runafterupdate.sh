#!/bin/sh

# This script is used to for configuration settings that we want to change during a SW update, that are not typically part of the update itself
# The script should include any waiting for dependencies that are required, and a self-cleanup at the end.
# If no changes are required, leave sections 1 and 2 below blank.
#

# 1.) Wait for dependencies - Leave BLANK if not needed


# 2.) Set configuration settings - Leave BLANK if not needed



# ########################################################################
# ## Self-Delete is required for this file, do not remove this section! ##
# ########################################################################

# Remove file from target after 1st run completion
mount -uw /fs/mmc0/
rm /fs/mmc0/app/bin/runafterupdate.sh
mount -ur /fs/mmc0/

# ########################################################################
