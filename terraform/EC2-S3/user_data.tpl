#cloud-boothook
#!/bin/bash
set -euo pipefail

LOG_FILE="/home/ubuntu/userdata.log"

sudo aws ec2 disassociate-address --region ${aws_region} --public-ip ${public_ip} >>"${LOG_FILE}" 2>&1 || true
sudo aws ec2 associate-address --region ${aws_region} --instance-id "$(cat /sys/devices/virtual/dmi/id/board_asset_tag)" --allocation-id ${allocation_id} >>"${LOG_FILE}" 2>&1

cat > /home/ubuntu/user.sh <<'EOL'
{
    "Comment": "Update record to reflect new IP address",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${record_fqdn}",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "${public_ip}"
                    }
                ]
            }
        }
    ]
}
EOL

aws route53 change-resource-record-sets --hosted-zone-id ${route53_zone_id} --change-batch file:///home/ubuntu/user.sh >>"${LOG_FILE}" 2>&1
