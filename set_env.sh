# Repo root = directory of this script, so it works from any cwd
export LPDDR4_PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Synopsys tools -- defaults for the SoC Labs Soton servers.
# Export your own value before sourcing to override.
export DESIGNWARE_HOME=${DESIGNWARE_HOME:-/eda/synopsys/2022-23/RHELx86/VC-VIP-SOC_2022.12}
export VERDI_HOME=${VERDI_HOME:-/eda/synopsys/2022-23/RHELx86/VERDI_2022.06-SP2}

# Verdi must match the VCS release (FSDB PLI is linked at compile time)
case ":$PATH:" in
    *":$VERDI_HOME/bin:"*) ;;
    *) export PATH=$VERDI_HOME/bin:$PATH ;;
esac
