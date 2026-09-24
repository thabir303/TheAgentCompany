# Kom storage + free API diye TheAgentCompany locally chalano (Bangla adaptation guide)

Ei guide-ta tader jonno jara TheAgentCompany (TAC) nijer laptop/PC-te chalate chan, kintu:

1. disk space kom (full setup-e 30 GB+ lage, protiti task-e aro kichu GB),
2. paid API key nei, r local model chalanor moto GPU nei,
3. task gulo Bangla-y convert kore evaluate korte chan.

> Number gulo 2026-09-24 tarikh-e registry manifest theke mapa (compressed size). Free-tier limit
> ghono ghono change hoy, tai long run-er age nijer provider console-e ekbar check kore niben.

---

## 1. Storage keno eto lage?

### 1.1 Server image (ekbar-i lage)

| Image | Download size (compressed) | Kon task-e lage |
| --- | --- | --- |
| `servers-gitlab` | **~11.9 GB** | 71 ta task (`gitlab`) |
| Plane (backend + frontend + admin + space + proxy) | ~0.7 GB (+ postgres, minio, valkey) | 17 ta task (`plane`) |
| `servers-owncloud` + `collabora/code` | 0.47 GB + collabora | 70 ta task (`owncloud`) |
| RocketChat + MongoDB + redis-stack + NPC data | ~1-2 GB mot (anuman) | 79 ta task (`rocketchat`) |
| `servers-api-server` (controller) | 0.3 GB | shob task |

Disk-e extract hole size sadharonoto compressed size-er 2-3 gun hoy. Mane **storage-er shobcheye boro
khoroch GitLab** — ar eta 175 tar moddhe mattro 71 ta task-e lage.

### 1.2 Task image (prai free)

Shob task image `task-base-image:1.0.0` (0.65 GB) er upor bana. 12 ta task image-er layer check kore
dekha geche, protiti task base-er upor **mattro 0-40 MB** jog kore — Docker layer share kore, tai
10 ta task pull korleo ~0.65 GB + 10 × (0-40 MB) lage.

### 1.3 OpenHands runtime image (ashol "per-task" khoroch)

`evaluation/run_eval.py` OpenHands diye chale. OpenHands **protiti task image-er upor notun ekta runtime
image build kore** (micromamba, poetry env, Playwright Chromium, VS Code server...). Reference hishebe
`ghcr.io/all-hands-ai/runtime:0.42-nikolaik` ~2.8 GB compressed — tai protiti task-e extract kora
kayek GB + build cache jome. Task-er base image alada hoyay ek task-er cache arek task-e kaje lage na.

Tai "koyekta task chalalam ar disk bhore gelo" — er karon mulato: (a) GitLab + Plane, (b) protiti task-er
runtime image + build cache clean na kora, (c) Windows/Mac-e Docker Desktop-er virtual disk nije theke
choto na howa.

---

## 2. Solution: "lite" setup

### 2.1 Shudhu dorkari server chalan

175 tar moddhe **93 ta task GitLab ba Plane chara chole** (shudhu ownCloud/RocketChat ba kono service-i
lage na), ar **36 ta task-e shudhu ownCloud** (ba kichui na) lage.

```bash
cd servers
bash setup-lite.sh                 # ownCloud + RocketChat  -> 93 ta task chalano jabe
# ba
bash setup-lite.sh owncloud        # shudhu ownCloud (shobcheye choto) -> 36 ta task
# shob bondho + remove korte
bash setup-lite.sh --down
```

`setup-lite.sh` original `api-server`-ke `SKIP_SETUP=True` diye chalay, tai se GitLab/Plane pull/start
kore na, kintu task-er `init.sh` je reset/health-check endpoint (`localhost:2999`) use kore segulo
ager motoi kaaj kore. Mac/Windows-e Docker Desktop-e `Settings > Resources > Network > Enable host
networking` on thakte hobe (original setup-er motoi).

### 2.2 Shudhu oi task gulo chalan

```bash
cd evaluation
python generate_task_images.py --allowed-services owncloud,rocketchat --names-only --output lite_tasks.txt
# chaile file theke kichu task rekhe baki delete korun, tarpor:
sudo su   # run_eval.sh-er root lage (original README onujayi)
bash run_eval.sh \
  --agent-llm-config gemini-agent \
  --env-llm-config gemini-env \
  --task-list lite_tasks.txt \
  --condenser browser \
  --max-iterations 50 \
  --outputs-path outputs_en \
  --server-hostname localhost \
  --version 1.0.0
```

`run_eval.sh` protiti task-er por task image, OpenHands runtime image, volume ar build cache
(`docker builder prune -af`) muche fele, tai ek shathe mattro ekta task-er runtime disk-e thake.
Peak usage motamuti: lite server + ekta runtime image + OpenHands-er Python env.

### 2.3 Disk hygiene

```bash
docker system df            # ke koto jayga nicche
docker builder prune -af    # build cache
docker image prune -af      # use hocche na emon image (khub dorkar hole)
```

- **Windows (Docker Desktop + WSL2):** prune korleo `.vhdx` file nije choto hoy na. Docker Desktop quit
  kore `wsl --shutdown` din, tarpor PowerShell (admin) theke
  `Optimize-VHD -Path "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx" -Mode Full`
  (Windows Home-e `diskpart` -> `select vdisk file=...` -> `compact vdisk`). Path version bhede
  `...\Docker\wsl\data\ext4.vhdx` o hote pare.
- **C: drive choto hole:** Docker Desktop `Settings > Resources > Advanced > Disk image location` diye
  D: drive-e shoran. Linux-e `/etc/docker/daemon.json`-e `{"data-root": "/path/on/bigger/disk"}`.
- **RAM:** paper-e 8 vCPU / 32 GB (t3.2xlarge) use hoyeche. Lite setup 16 GB RAM-e chola uchit;
  8 GB-e kosto hobe (OpenHands runtime-e Chromium chole).

### 2.4 Tobuo jayga na hole: cloud VM

University email thakle GitHub Student Developer Pack diye (current offer check korun) Azure for Students
credit ba DigitalOcean credit pawa jay — ekta 4 vCPU / 16 GB / 100 GB disk-er Linux VM-e full setup
(GitLab shoho) arame chole, ar kaaj shesh hole VM delete kore dilei khoroch bondho. Note: TAC-er image
gulo shudhu `linux/amd64`, tai ARM VM (jemon Oracle free Ampere) e emulation lagbe, khub slow.

---

## 3. Free API diye chalano

### 3.1 Duita alada LLM lage

| Role | Ki kore | Ki dorkar |
| --- | --- | --- |
| **Agent LLM** (`--agent-llm-config`) | task-ta kore (je model-ke evaluate korchen) | protiti task-e ~20-50 ta request, prompt protiti step-e baray (full history) -> boro context, beshi **tokens-per-minute** |
| **Environment LLM** (`--env-llm-config`) | RocketChat-e NPC coworker hoy + kichu checkpoint grade kore | kom request, kintu **Bangla bujhte hobe** (NPC/bot-er shathe Bangla-y kotha hole); **OpenAI-compatible endpoint** hote hobe |

Environment LLM task container-er vitore purono litellm (1.23.16) + sotopia diye call hoy, tai
`base_url` dite hobe ar model-er age `openai/` lagbe (`evaluation/config.toml.example` dekhun).

Paper-er baseline-e (Claude 3.5 Sonnet) task prati prai 30 step ar ~$6 khoroch hoyechilo — mane ekta
task-e million-er upor input token jete pare. Free tier-e eta komate:

- `--condenser browser`: purono browser page (accessibility tree, onek boro) mask kore, shudhu shesh-ta
  rakhe. Browsing-heavy task-e token onek kome; agent purono page abar porte chaile page-e fire jete hoy.
  Eta baseline setting na, tai je setting use korben seta report korun.
- `--max-iterations 40-50`: baseline 100; free tier-e 40-50 rakhle quota bache.
- `config.toml`-e `num_retries = 10`, `retry_min_wait = 20`, `retry_max_wait = 120`: HTTP 429 pele
  OpenHands wait kore abar try kore, task fail kore na.

### 3.2 Provider comparison (September 2026)

| Provider | Free limit (approx.) | Agent LLM | Env LLM | Mantobbo |
| --- | --- | --- | --- | --- |
| **Google AI Studio (Gemini Flash / Flash-Lite)** | model-wise RPM/RPD, 1M context, TPM beshi. Dec 2025-e limit onek komano hoyechilo, nijer quota AI Studio-te dekhun | ✅ best | ✅ (OpenAI-compatible endpoint) | Bangla-y free model gular moddhe shobcheye bhalo. Free tier-er data Google training-e use korte pare |
| **NVIDIA NIM** (build.nvidia.com) | ~40 RPM, daily cap publish kora nei | ✅ bhalo backup | ✅ | gpt-oss-120b, Llama-3.3-70B, Qwen, Nemotron ityadi. Bangla Gemini-r cheye durbol |
| **OpenRouter** `:free` model | 20 RPM, din-e **50 ta** free request (ekbar $10 credit kinle 1000) | ⚠️ din-e ~1 task | ✅ | credit chara boro run-er jonno kom |
| **Groq** | 30 RPM, 1000 RPD, kintu gpt-oss-120b-e **8K tokens/min** | ❌ | ⚠️ | agent-er ekta prompt-i 8K token chariye jay -> reject |
| **Mistral** (free plan) | limit console-e dekhay | ⚠️ | ✅ | free-plan data training-e use hote pare (opt-out ache) |
| Cerebras | ekhon shudhu trial credit | ❌ | ❌ | long-term free na |
| Cloudflare Workers AI | 10K neurons/din | ❌ | ❌ | khub kom |

Rough hishab: **din-e koyta task = agent model-er RPD ÷ ~40-50**. Tai RPD-i ashol bottleneck.

### 3.3 Recommended combination

- **Agent:** Gemini Flash (`[llm.gemini-agent]`). Quota shesh hole NVIDIA NIM (`[llm.nim-agent]`).
- **Environment:** Gemini Flash-Lite, OpenAI-compatible endpoint diye (`[llm.gemini-env]`). Agent theke
  alada model hoyay alada per-model quota pay. Agent-er quota bachate chaile NIM (`[llm.nim-env]`),
  kintu Bangla NPC-er jonno Gemini bhalo.
- Eksathe duita task parallel chalaben na — free-tier RPM ek shathe shesh hoye jabe.

```bash
cd evaluation
cp config.toml.example config.toml      # key boshan (config.toml git-ignored)
poetry run python check_llm_config.py --agent-llm-config gemini-agent --env-llm-config gemini-env
```

`check_llm_config.py` protiti group-e ekta Bangla prompt pathay; key/model name/`base_url` vul ba quota
shesh hole ekhanei dhora pore, task-er majhkhane na.

### 3.4 Shabdhan: rate limit "chupchap" fail

- LLM-based evaluator (`evaluate_with_llm`) API error (429 shoho) pele exception na chhure `False`
  return kore -> checkpoint fail dekhay. Result sondehojonok hole
  `grep -i "Failed to evaluate\|RateLimit" <log>` kore dekhun, dorkar hole task-ta abar chalan.
- NPC-er LLM rate-limited hole NPC reply-i dey na, agent-er kache mone hoy keu uttor dicche na.

---

## 4. Bangla task banano

### 4.1 Workflow

```bash
# 1) task copy + English instruction task.en.md hishebe rakha
bash workspaces/make_translated_task.sh hr-salary-analysis
# 2) workspaces/tasks_bn/hr-salary-analysis/task.bn.md e Bangla onubad likhun
#    (NPC task hole chaile scenarios.bn.json o)
# 3) abar chalan -> task.bn.md -> task.md, image build: tac-bn/hr-salary-analysis-image:1.0.0
bash workspaces/make_translated_task.sh hr-salary-analysis
```

Tarpor:

```bash
cd evaluation
echo hr-salary-analysis > bn_tasks.txt
bash run_eval.sh --image-prefix tac-bn --task-list bn_tasks.txt --outputs-path outputs_bn \
  --agent-llm-config gemini-agent --env-llm-config gemini-env --condenser browser --max-iterations 50
```

Local image (`--image-prefix` default na hole) run-er por delete hoy na, karon abar pull kora jay na.
English ar Bangla result alada folder-e rakhun (`outputs_en`, `outputs_bn`), tarpor
`poetry run python summarise_results.py outputs_bn` diye tulona korun.

### 4.2 Ki onubad korben, ki korben na

- **Onubad korun:** instruction-er bhasha, NPC-er `extra_info`/`strategy_hint`
  (chaile likhe din "Always reply in Bangla").
- **Onubad korben na:** URL, file/folder name (`/workspace/ans.txt`, `Documents/Admin`), username,
  channel name, number, required output format. Evaluator egulo hubohu string match kore.
- Kichu evaluator agent-er chat message-e English keyword khoje. Agent Bangla-y likhle segulo fail
  korbe. Duita upay: instruction-e boli "reply in English" (shudhu instruction Bangla), ba
  `workspaces/tasks_bn/<task>/evaluator.py`-e Bangla keyword o accept korun — image apni nije build
  korchen, tai edit kora evaluator-i encrypt hoye image-e jabe. Je poriborton korben ta paper-e
  report korun.
- `checkpoints.md` porle bujhben evaluator ki check kore.

### 4.3 Kon task diye shuru korben

Shudhu ownCloud (ba kono service na), NPC nei, LLM grader nei — deterministic grading, tai Bangla vs
English tulona shobcheye porishkar (29 ta):

```
admin-make-spreadsheet, admin-mass-forms-filling, admin-remove-pages-pdf, admin-translate-sales-chat,
admin-watch-video, ds-coffee-shop-database-management, ds-find-meeting-spreadsheet,
ds-fix-table-values-and-missing-answers, ds-format-excel-sheets, ds-predictive-modeling, ds-sql-exercise,
finance-budget-variance, finance-check-attendance-payroll, finance-expense-validation,
finance-invoice-matching, finance-nonqualified-bill-ask-for-reimburse, hr-check-attendance-multiple-days,
hr-check-attendance-multiple-days-department, hr-check-attendance-one-day, hr-organize-talent-info,
hr-populate-salary-increase-memo, hr-resume-categorization, hr-salary-analysis, ml-grade-exam,
sde-copy-table-from-pdf-to-xlsx, sde-create-sqlite-database, sde-install-go, sde-install-openjdk,
sde-run-rising-wave-locally
```

Eta `bash setup-lite.sh owncloud` diyei chole. Porer dhape RocketChat/NPC task (Bangla conversation).

### 4.4 OpenHands chara ekta task haate test kora

Onubad thik ache kina ba evaluator Bangla output accept kore kina dekhte OpenHands runtime build-er
dorkar nei (disk-o lage na):

```bash
docker run --name bn-test --network host -it tac-bn/hr-salary-analysis-image:1.0.0 /bin/bash
# container-er vitore:
SERVER_HOSTNAME=localhost LITELLM_API_KEY=<key> \
LITELLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/ \
LITELLM_MODEL=openai/gemini-2.5-flash-lite bash /utils/init.sh
cat /instruction/task.md
# ... nije task-ta korun (ba bhul kore dekhun) ...
DECRYPTION_KEY='theagentcompany is all you need' LITELLM_API_KEY=<key> \
LITELLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/ \
LITELLM_MODEL=openai/gemini-2.5-flash-lite python_default /utils/eval.py --result_path /tmp/result.json
cat /tmp/result.json
```

---

## 5. Suggested plan

1. `bash servers/setup-lite.sh owncloud` + `check_llm_config.py` diye key test.
2. English-e 3-5 ta task (upore list theke) `--condenser browser --max-iterations 50` diye chalan —
   pipeline thik ache kina, protiti task-e koto request/token lagche dekhun.
3. Oi task gulo Bangla-y banan (section 4), haate test korun (4.4), tarpor same model + same flag diye
   `outputs_bn`-e chalan.
4. Bhalo chole RocketChat add korun (`bash servers/setup-lite.sh`) ar NPC task-e jan.
