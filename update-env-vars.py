#!/usr/bin/env python3
"""
Update ECS Task Definition with environment variables
"""
import json
import sys
import os

def update_task_definition(task_def_file, groq_key=None, tavily_key=None):
    """Update task definition with environment variables"""
    
    with open(task_def_file, 'r') as f:
        task_def = json.load(f)
    
    container_def = task_def['containerDefinitions'][0]
    
    # Get existing environment variables
    env_vars = container_def.get('environment', [])
    
    # Remove existing keys if present
    env_vars = [e for e in env_vars 
                if e.get('name') not in ['GROQ_API_KEY', 'TAVILY_API_KEY']]
    
    # Add new environment variables
    if groq_key:
        env_vars.append({'name': 'GROQ_API_KEY', 'value': groq_key})
        print("✅ Added GROQ_API_KEY")
    
    if tavily_key:
        env_vars.append({'name': 'TAVILY_API_KEY', 'value': tavily_key})
        print("✅ Added TAVILY_API_KEY")
    
    container_def['environment'] = env_vars
    
    # Remove fields that can't be set when registering new revision
    for key in ['taskDefinitionArn', 'revision', 'status', 'requiresAttributes', 
                'compatibilities', 'registeredAt', 'registeredBy']:
        task_def.pop(key, None)
    
    # Save updated task definition
    output_file = 'task-def-updated.json'
    with open(output_file, 'w') as f:
        json.dump(task_def, f, indent=2)
    
    print(f"\n✅ Updated task definition saved to {output_file}")
    print(f"   Environment variables: {[e['name'] for e in env_vars]}")
    
    return output_file

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 update-env-vars.py <task-def.json> [GROQ_API_KEY] [TAVILY_API_KEY]")
        print("\nOr set environment variables:")
        print("  export GROQ_API_KEY='gsk_...'")
        print("  export TAVILY_API_KEY='tvly-dev-...'")
        print("  python3 update-env-vars.py task-def.json")
        sys.exit(1)
    
    task_def_file = sys.argv[1]
    
    # Get keys from args or environment
    groq_key = sys.argv[2] if len(sys.argv) > 2 else os.getenv('GROQ_API_KEY')
    tavily_key = sys.argv[3] if len(sys.argv) > 3 else os.getenv('TAVILY_API_KEY')
    
    # Prompt if not provided
    if not groq_key:
        groq_key = input("Enter GROQ_API_KEY (or press Enter to skip): ").strip() or None
    
    if not tavily_key:
        tavily_key = input("Enter TAVILY_API_KEY (or press Enter to skip): ").strip() or None
    
    if not groq_key and not tavily_key:
        print("⚠️  No API keys provided. Exiting.")
        sys.exit(1)
    
    update_task_definition(task_def_file, groq_key, tavily_key)


