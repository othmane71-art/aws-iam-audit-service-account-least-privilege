# Crée volontairement des configurations dangereuses à auditer.
# LocalStack uniquement : ne jamais exécuter sur un compte AWS réel.

if (-not $env:AWS_ENDPOINT_URL) { throw "Refus : LocalStack uniquement" }

@'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"s3:*","Resource":"*"}]}
'@ | Set-Content -Encoding ascii tout-s3.json
@'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:Get*","s3:List*"],"Resource":"*"}]}
'@ | Set-Content -Encoding ascii lecture-large.json
@'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"*"},"Action":"sts:AssumeRole"}]}
'@ | Set-Content -Encoding ascii confiance-ouverte.json
@'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}
'@ | Set-Content -Encoding ascii tout-pour-tous.json

aws iam create-user --user-name stagiaire | Out-Null
aws iam attach-user-policy --user-name stagiaire --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-user --user-name devops | Out-Null
aws iam put-user-policy --user-name devops --policy-name tout-s3 --policy-document file://tout-s3.json
aws iam create-user --user-name ancien-presta | Out-Null
aws iam create-access-key --user-name ancien-presta | Out-Null
aws iam create-access-key --user-name ancien-presta | Out-Null
aws iam create-user --user-name compta-jane | Out-Null
aws iam put-user-policy --user-name compta-jane --policy-name lecture-large --policy-document file://lecture-large.json
aws iam create-role --role-name role-ouvert --assume-role-policy-document file://confiance-ouverte.json | Out-Null
aws iam attach-role-policy --role-name role-ouvert --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-policy --policy-name tout-pour-tous --policy-document file://tout-pour-tous.json | Out-Null

Remove-Item tout-s3.json, lecture-large.json, confiance-ouverte.json, tout-pour-tous.json
"Environnement désordonné créé."
