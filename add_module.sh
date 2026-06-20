if [ $# -eq 0 ]; then
    echo "Error: No argument provided. Usage: $0 <Project Name> <Module Name>"
    exit 1
fi

PROJECT_NAME=$1

# Create Module
echo "module $2 where" > app/$2.hs

# Add it to Cabal File
sed "s/other-modules:.*/& $2/" $PROJECT_NAME.cabal > tmp && mv tmp $PROJECT_NAME.cabal

# Update HIE
gen-hie > hie.yaml