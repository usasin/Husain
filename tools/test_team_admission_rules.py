#!/usr/bin/env python3
"""Run only against the local demo-prono4 Firestore emulator. No live credentials."""
import base64,json,time,urllib.request,urllib.error
BASE='http://127.0.0.1:8080/v1/projects/demo-prono4/databases/(default)/documents'
DB='projects/demo-prono4/databases/(default)/documents/'
passed=[]
def token(uid):
 if uid=='owner':return 'owner'
 def enc(x):return base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')
 return enc({'alg':'none','typ':'JWT'})+'.'+enc({'sub':uid,'user_id':uid,'aud':'demo-prono4','iss':'https://securetoken.google.com/demo-prono4','iat':int(time.time()),'exp':int(time.time())+3600,'firebase':{'sign_in_provider':'custom'}})+'.'
def val(x):
 if x is None:return {'nullValue':None}
 if isinstance(x,bool):return {'booleanValue':x}
 if isinstance(x,int):return {'integerValue':str(x)}
 if isinstance(x,list):return {'arrayValue':{'values':[val(y) for y in x]}}
 return {'stringValue':x}
def request(uid,path='',data=None,method='GET'):
 headers={'Content-Type':'application/json'}
 if uid is not None:headers['Authorization']='Bearer '+token(uid)
 req=urllib.request.Request(BASE+path,data=None if data is None else json.dumps(data).encode(),headers=headers,method=method)
 try:
  with urllib.request.urlopen(req,timeout=10) as res:return res.status,json.load(res)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def seed(path,data):
 status,body=request('owner','/'+path,{'fields':{k:val(v) for k,v in data.items()}},'PATCH');assert status==200,(status,body)
def write(path,data,stamps=()):
 return {'update':{'name':DB+path,'fields':{k:val(v) for k,v in data.items()}},'updateMask':{'fieldPaths':list(data)+list(stamps)},'updateTransforms':[{'fieldPath':s,'setToServerValue':'REQUEST_TIME'} for s in stamps]}
def commit(uid,writes):return request(uid,':commit',{'writes':writes},'POST')
def check(name,result,expected):
 status,body=result
 assert status==expected,(name,status,body)
 passed.append(name);print('PASS',name,flush=True)
def setup(team='t',members=('member',),locked=False,candidate_team=None):
 seed('teams/'+team,{'memberIds':list(members),'name':'Existing team','imageB64':'saved-team-image','createdBy':'member','code':'EXISTING','isLocked':locked})
 for uid in members:seed('users/'+uid,{'name':uid,'avatar':'saved-avatar','teamId':team,'isAdmin':False,'points':42,'recoveryCode':'EXIST123'})
 seed('users/candidate',{'name':'Candidate','avatar':'saved-candidate-avatar','teamId':candidate_team,'isAdmin':False,'points':99,'recoveryCode':'CAND1234'})
def apply(team='t',user='candidate',extra=None):
 data={'userId':user,'authUid':user,'name':'Candidate','avatar':'photo','status':'pending',**(extra or {})}
 return write('teams/'+team+'/joinRequests/'+user,data,['requestedAt'])
def decision(team='t',actor='member',status='accepted',members=('member','candidate'),extra_user=None,parts=(1,2,3)):
 writes=[write('teams/'+team,{'memberIds':list(members)},['updatedAt']),write('users/candidate',{'teamId':team,**(extra_user or {})},['updatedAt']),write('teams/'+team+'/joinRequests/candidate',{'status':status,'reviewedBy':actor},['reviewedAt'])]
 return [writes[i-1] for i in parts]
setup()
check('unauthenticated request rejected',commit(None,[apply()]),403)
check('required name cannot be omitted',commit('candidate',[write('teams/t/joinRequests/candidate',{'userId':'candidate','authUid':'candidate','avatar':'photo','status':'pending'},['requestedAt'])]),403)
check('extra schema field rejected',commit('candidate',[apply(extra={'isAdmin':True})]),403)
check('wrong avatar type rejected',commit('candidate',[apply(extra={'avatar':123})]),403)
check('wrong requestedAt type rejected',commit('candidate',[write('teams/t/joinRequests/candidate',{'userId':'candidate','authUid':'candidate','name':'Candidate','avatar':'photo','status':'pending','requestedAt':'invalid'})]),403)
check('candidate reads absent request for transaction',request('candidate','/teams/t/joinRequests/candidate'),404)
check('candidate creates own pending request',commit('candidate',[apply()]),200)
check('member reads pending request',request('member','/teams/t/joinRequests/candidate'),200)
check('outsider cannot read another request',request('outsider','/teams/t/joinRequests/candidate'),403)
check('outsider cannot forge candidate identity',commit('outsider',[apply('t','victim')]),403)
check('spoofed authUid is rejected',commit('outsider',[apply('t','outsider',{'authUid':'candidate'})]),403)
check('outsider cannot forge membership authority',commit('outsider',[write('teams/t',{'memberIds':['member','outsider']})]),403)
check('outsider cannot delete and recreate the team',request('outsider','/teams/t',method='DELETE'),403)
check('creator cannot invent another member on creation',commit('outsider',[write('teams/forged',{'createdBy':'outsider','memberIds':['member','outsider']})]),403)
check('candidate cannot self-approve',commit('candidate',decision(actor='candidate')),403)
check('outsider cannot approve',commit('outsider',decision(actor='outsider')),403)
check('accept without team/profile changes rejected',commit('member',decision(parts=(3,))),403)
check('accept without profile change rejected',commit('member',decision(parts=(1,3))),403)
check('accept with role escalation rejected',commit('member',decision(extra_user={'isAdmin':True})),403)
check('member atomically admits candidate',commit('member',decision()),200)
for path,keys in [('users/candidate',{'avatar':'saved-candidate-avatar','points':99,'recoveryCode':'CAND1234'}),('teams/t',{'imageB64':'saved-team-image','code':'EXISTING'})]:
 status,body=request('owner','/'+path);assert status==200
 for key,value in keys.items():assert body['fields'][key]==val(value),(path,key,body)
passed.append('points/recovery code/avatars/team image preserved');print('PASS',passed[-1])
check('accepted request cannot be rejected again',commit('member',decision(status='rejected',parts=(3,))),403)
setup('locked',locked=True)
check('locked team refuses requests',commit('candidate',[apply('locked')]),403)
setup('full',members=('member','two','three','four'))
check('full team refuses requests',commit('candidate',[apply('full')]),403)
setup('reject')
check('request can be sent for review',commit('candidate',[apply('reject')]),200)
check('member rejects without changing profile',commit('member',decision(team='reject',status='rejected',parts=(3,))),200)
check('candidate resubmits rejected request',commit('candidate',[apply('reject')]),200)
check('oversized name rejected on update',commit('candidate',[apply('reject',extra={'name':'x'*81})]),403)
setup('other',candidate_team='different-team')
check('player in another team cannot request admission',commit('candidate',[apply('other')]),403)
query={'structuredQuery':{'from':[{'collectionId':'joinRequests'}],'where':{'fieldFilter':{'field':{'fieldPath':'status'},'op':'EQUAL','value':val('pending')}},'limit':30}}
check('member pending-request query allowed',request('member','/teams/reject:runQuery',query,'POST'),200)
check('outsider pending-request query rejected',request('outsider','/teams/reject:runQuery',query,'POST'),403)
setup('race',members=('member','two','three'))
check('request sent before team fills',commit('candidate',[apply('race')]),200)
seed('teams/race',{'memberIds':['member','two','three','four'],'name':'Existing team','createdBy':'member','code':'EXISTING','isLocked':False})
check('concurrent full team cannot accept a fifth player',commit('member',decision(team='race',members=('member','two','three','four','candidate'))),403)
check('new team creation for own UID preserved',commit('outsider',[write('teams/own',{'createdBy':'outsider','memberIds':['outsider'],'name':'Own team','code':'CODE','imageB64':'photo'})]),200)
seed('users/outsider',{'name':'Outsider','teamId':'own','isAdmin':False})
check('team image update preserved',commit('outsider',[write('teams/own',{'imageB64':'new-photo'})]),200)
check('last member can leave and delete team',commit('outsider',[write('users/outsider',{'teamId':None}),{'delete':DB+'teams/own'}]),200)
setup('leave',members=('member','two'))
check('member can leave a multi-member team',commit('member',[write('teams/leave',{'memberIds':['two']}),write('users/member',{'teamId':None})]),200)
print('ALL',len(passed),'CHECKS PASSED')
