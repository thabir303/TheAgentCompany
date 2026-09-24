"""
Sanity-check LLM groups in config.toml before starting a long evaluation run.

For each group it sends one short Bangla prompt and prints the reply, latency
and token usage, so wrong model names, bad keys, missing base_url or exhausted
free-tier quotas show up in seconds instead of in the middle of a task.

Usage (from the evaluation directory):
    poetry run python check_llm_config.py --agent-llm-config gemini-agent --env-llm-config gemini-env
"""
import argparse
import sys
import time

import litellm
from openhands.core.config import get_llm_config_arg

PROMPT = 'এক বাক্যে বলুন: বাংলাদেশের রাজধানীর নাম কী?'  # "In one sentence: what is the capital of Bangladesh?"


def check(group: str, config_file: str, is_env: bool) -> bool:
    role = 'environment' if is_env else 'agent'
    print(f'== [{role}] llm.{group}')
    config = get_llm_config_arg(group, config_file)
    if config is None:
        print(f'   FAIL: [llm.{group}] not found in {config_file}')
        return False
    if config.api_key is None:
        print('   FAIL: api_key is not set')
        return False
    print(f'   model={config.model} base_url={config.base_url}')

    if is_env:
        # The task containers call the environment LLM through an old litellm
        # and sotopia's OpenAI client, which only work with an OpenAI-compatible
        # endpoint given as base_url + "openai/<model>".
        if not config.base_url:
            print('   FAIL: environment LLM needs base_url (OpenAI-compatible endpoint)')
            return False
        if not config.model.startswith('openai/'):
            print('   FAIL: environment LLM model must start with "openai/"')
            return False

    start = time.time()
    try:
        response = litellm.completion(
            model=config.model,
            api_key=config.api_key.get_secret_value(),
            base_url=config.base_url,
            messages=[{'role': 'user', 'content': PROMPT}],
            max_tokens=1024,
            num_retries=0,
        )
    except Exception as e:
        print(f'   FAIL after {time.time() - start:.1f}s: {type(e).__name__}: {str(e)[:500]}')
        return False

    content = (response.choices[0].message.content or '').strip()
    usage = getattr(response, 'usage', None)
    print(f'   OK in {time.time() - start:.1f}s, usage={usage}')
    print(f'   reply: {content[:300]}')
    return True


def main():
    parser = argparse.ArgumentParser(description='Check LLM groups in config.toml')
    parser.add_argument('--agent-llm-config', help='agent LLM group name in config.toml')
    parser.add_argument('--env-llm-config', help='environment LLM group name in config.toml')
    parser.add_argument('--config-file', default='config.toml', help='path to config.toml')
    args = parser.parse_args()

    if not args.agent_llm_config and not args.env_llm_config:
        parser.error('give --agent-llm-config and/or --env-llm-config')

    ok = True
    if args.agent_llm_config:
        ok = check(args.agent_llm_config, args.config_file, is_env=False) and ok
    if args.env_llm_config:
        ok = check(args.env_llm_config, args.config_file, is_env=True) and ok
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
