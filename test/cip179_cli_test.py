import json, os, pathlib, pty, select, subprocess, tempfile, time, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
(ROOT/'.test-artifacts').mkdir(exist_ok=True)
TX='11'*32
class VotingHelper(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(dir=ROOT/'.test-artifacts');self.addCleanup(self.tmp.cleanup)
        self.dir=pathlib.Path(self.tmp.name);self.out=self.dir/'response.json'
        self.node='node';self.helper=ROOT/'cardano/testnet/cip179-vote.mjs'
    def respond(self,fixture='single',prompts=(),index='0',role='0',expiry='500',fixture_path=None):
        native=self.dir/'native.json'
        tx_id=subprocess.check_output([str(self.node),str(ROOT/'test/native-fixture.mjs'),str(fixture_path or ROOT/f'test/fixtures/cli-{fixture}.json'),str(native)],text=True)
        env={**os.environ,'AUDIT_CLI_FIXTURE':str(native),'CIP179_KOIOS_API':'https://fixture.invalid'}
        master,slave=pty.openpty()
        proc=subprocess.Popen([str(self.node),'--import',str(ROOT/'test/cli-fetch.mjs'),str(self.helper),'respond',tx_id,index,role,'22'*28,expiry,str(self.out)],stdin=slave,stdout=slave,stderr=slave,env=env)
        os.close(slave);data=b'';offset=0;pending=list(prompts);deadline=time.monotonic()+10
        try:
            while time.monotonic()<deadline:
                if select.select([master],[],[],.1)[0]:
                    try: chunk=os.read(master,65536)
                    except OSError: break
                    if not chunk: break
                    data+=chunk
                    if pending and pending[0][0].encode() in data[offset:]:
                        _,answer=pending.pop(0);offset=len(data);os.write(master,(answer+'\n').encode())
                if proc.poll() is not None: break
            # A PTY can close just before waitpid observes the child's exit.
            try: proc.wait(timeout=max(.1,deadline-time.monotonic()))
            except subprocess.TimeoutExpired:
                proc.kill();proc.wait();raise AssertionError('CLI timed out: '+data.decode(errors='replace'))
        finally:
            if proc.poll() is None: proc.kill();proc.wait()
            os.close(master)
        (ROOT/'.test-artifacts/script-cases').mkdir(exist_ok=True)
        (ROOT/'.test-artifacts/script-cases'/self.id().split('.')[-1]).write_bytes(data)
        return proc.returncode,data.decode(errors='replace')
    def test_single_choice(self):
        code,log=self.respond(prompts=[('Choose one option.','2'),('(Y/n):','y')]);self.assertEqual(code,0,log)
        doc=json.loads(self.out.read_text());self.assertEqual(doc['17']['list'][0],{'int':1})
        (ROOT/'.test-artifacts/cli-response.json').write_text(json.dumps(doc,indent=2)+'\n')
    def test_explicit_empty_multi(self): self.assertEqual(self.respond('multi',[('empty selection).','none'),('(Y/n):','y')])[0],0)
    def test_AUD_S02_all_omitted_rejected(self): self.assertNotEqual(self.respond('optional',[('Press Enter to abstain.',''),('(Y/n):','y')])[0],0)
    def test_numeric_reprompts_off_grid(self): self.assertEqual(self.respond('numeric',[('in steps of 2.','3'),('in steps of 2.','-2'),('(Y/n):','y')])[0],0)
    def test_ranking(self): self.assertEqual(self.respond('ranking',[('comma-separated.','2,1'),('(Y/n):','y')])[0],0)
    def test_points_reprompts_wrong_total(self): self.assertEqual(self.respond('points',[('(example: 1=5,2=5).','1=2,2=7'),('(example: 1=5,2=5).','1=3,2=7'),('(Y/n):','y')])[0],0)
    def test_rating_requires_all_and_accepts_zero(self): self.assertEqual(self.respond('rating',[('Every option must be rated.','1=0'),('Every option must be rated.','1=0,2=5'),('(Y/n):','y')])[0],0)
    def test_cancel_produces_no_metadata(self):
        code,log=self.respond(prompts=[('Choose one option.','1'),('(Y/n):','n')]);self.assertEqual(code,10,log);self.assertFalse(self.out.exists())
    def test_wrong_expiry(self): self.assertNotEqual(self.respond(expiry='501')[0],0)
    def test_wrong_role(self): self.assertNotEqual(self.respond(role='3')[0],0)
    def test_wrong_index(self): self.assertNotEqual(self.respond(index='65536')[0],0)
    def test_does_not_overwrite_response(self):
        self.out.write_text('keep');self.assertNotEqual(self.respond(prompts=[('Choose one option.','1'),('(Y/n):','y')])[0],0);self.assertEqual(self.out.read_text(),'keep')
    def test_AUD_S03_malformed_merge_response_rejected(self):
        src=self.dir/'malformed.json';src.write_text(json.dumps({'17':{'list':[{'int':1},{'list':[{'int':42}]}]}}))
        r=subprocess.run([str(self.node),str(self.helper),'merge',str(self.out),str(src)],capture_output=True,text=True,timeout=10)
        self.assertNotEqual(r.returncode,0,r.stdout+r.stderr)
    def test_mainnet_testnet_helper_identical(self): self.assertEqual(self.helper.read_bytes(),(ROOT/'cardano/mainnet/cip179-vote.mjs').read_bytes())


    def test_large_integer_definition_is_readable(self):
        document=json.loads((ROOT/'test/fixtures/cli-single.json').read_text())
        document[0]['metadata']['17'][1][0]['7'][0]=[4,'Large range',[0,9223372036854775807],1]
        fixture=self.dir/'large.json';fixture.write_text(json.dumps(document))
        code,log=self.respond(fixture_path=fixture,prompts=[('Enter an integer','9007199254740993'),('(Y/n):','y')])
        self.assertEqual(code,0,log)
        self.assertIn('9007199254740993',self.out.read_text())
        merged=self.dir/'merged.json'
        result=subprocess.run([self.node,str(self.helper),'merge',str(merged),str(self.out)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(merged.read_text())['17'],json.loads(self.out.read_text())['17'])
        self.assertNotIn('_cip179',json.loads(merged.read_text()))
    def test_terminal_prompt_is_escaped(self):
        document=json.loads((ROOT/'test/fixtures/cli-single.json').read_text())
        document[0]['metadata']['17'][1][0]['7'][0][1]='\x1b[2J\x1b[HInjected'
        fixture=self.dir/'terminal.json';fixture.write_text(json.dumps(document))
        code,log=self.respond(fixture_path=fixture,prompts=[('Choose one option.','1'),('(Y/n):','y')])
        self.assertEqual(code,0,log);self.assertNotIn('\x1b[2J\x1b[H',log)

class HostIntegration(unittest.TestCase):
    """Execute the exact host blocks without entering signing or action submission."""
    def anchor(self, body):
        source=(ROOT/'cardano/testnet/25a_genAction.sh').read_text()
        start=source.index("if jq -e '.body.cip179 != null and")
        end=source.index('contentHASH=',start)
        with tempfile.TemporaryDirectory(dir=ROOT/'.test-artifacts') as directory:
            path=pathlib.Path(directory)/'anchor.json';path.write_text(json.dumps({'body':body}))
            return subprocess.run(['bash','-c',source[start:end]],env={**os.environ,'tmpAnchorContent':str(path)},capture_output=True,text=True)
    def test_link_without_cip169_is_accepted(self):
        self.assertEqual(self.anchor({'cip179':{'specVersion':5}}).returncode,0)
    def test_partial_cip169_is_rejected(self):
        self.assertNotEqual(self.anchor({'cip179':{},'onChain':{'deposit':'1000000000'}}).returncode,0)
    def test_complete_cip169_is_accepted(self):
        self.assertEqual(self.anchor({'cip179':{},'onChain':{'deposit':'1000000000','reward_account':'stake_test1fixture'}}).returncode,0)
    def test_live_parameters_and_return_account_must_match(self):
        source=(ROOT/'cardano/testnet/25a_genAction.sh').read_text()
        start=source.index('if [[ "${cip179AnchorDeposit}" != "" ]]')
        end=source.index('\necho -e',start)
        env={**os.environ,'cip179AnchorDeposit':'1000','actionDepositFee':'1000','cip179AnchorRewardAccount':'same','stakeAddr':'same'}
        for changed,expected in [({},0),({'actionDepositFee':'2000'},1),({'stakeAddr':'different'},1)]:
            result=subprocess.run(['bash','-c',source[start:end]],env={**env,**changed},capture_output=True,text=True)
            self.assertEqual(result.returncode,expected,result.stdout+result.stderr)
    def test_plain_and_encrypted_cip20_messages_are_preserved(self):
        source=(ROOT/'cardano/testnet/24b_regVote.sh').read_text()
        expression='with_entries('+source.split("tmp=$(jq 'with_entries(",1)[1].split("' <<<",1)[0]
        for message in [{'674':{'msg':['hello','world']}},{'674':{'enc':'basic','msg':['ciphertext']}}]:
            result=subprocess.run(['jq',expression],input=json.dumps(message),capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            decoded={entry['k']['string']:[item['string'] for item in entry['v']['list']] if 'list' in entry['v'] else entry['v']['string'] for entry in json.loads(result.stdout)['674']['map']}
            self.assertEqual(decoded,message['674'])

if __name__=='__main__': unittest.main(verbosity=2)
