
# The alias' and details of the CI Machines
# "local port:ssh username:shh host"
mini1="5921:administrator:208.52.187.216"
mini2="5922:administrator:208.52.187.217"
mini3="5923:administrator:208.52.187.218"
mini4="5924:administrator:208.52.187.175"
mini5="5925:administrator:208.52.187.248"
mini6="5926:administrator:208.52.187.249"
mini7="5927:administrator:208.52.187.19"
mini8="5928:administrator:208.52.187.20"
mini9="5929:administrator:208.52.187.21"
pro1="5931:administrator:208.52.187.179"
pro3="5933:administrator:208.52.187.103"
android1="5941:administrator:208.52.187.102"
 
deets_string=${!1}
deets=(${deets_string//:/ })
 
if [[ $2 = "vnc" ]]; then
  if [[ ${deets[0]} && ${deets[1]} && ${deets[2]} ]]; then
    ps axww | grep ssh | grep -q "${deets[0]}:127.0.0.1:5900"
    if [ $? != 0 ] ; then
      # ssh port forwarding not running, so start over
      ssh -N -f -L ${deets[0]}:127.0.0.1:5900 ${deets[1]}@${deets[2]}
    fi
 
    open vnc://127.0.0.1:${deets[0]}
  else
    echo "Invalid CI machine details"
  fi
else
  ssh ${deets[1]}@${deets[2]}
fi
