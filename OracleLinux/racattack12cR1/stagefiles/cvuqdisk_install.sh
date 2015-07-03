if [ -f /media/sf_12cR1/grid/rpm/cvuqdisk-1.0.9-1.rpm ] ; then
	rpm -q cvuqdisk 2>/dev/null >/dev/null
	if [ $? -eq 0 ]; then
		echo "cvuqdisk found installed, skipping.."
	else
		yum --disableplugin='*' -C --disablerepo='*' localinstall -y /u01/stage/grid/rpm/cvuqdisk-1.0.9-1.rpm
	fi
else
  echo "this script require the Grid 12cR1 binaries unzipped in /media/sf_12cR1 !"
  exit 1
fi


