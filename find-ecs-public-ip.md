# How to Find ECS Task Public IP

## Step 1: Click on the Task ID

1. In the **Tasks** tab, click on the **Task ID**: `1f0060a010b24bd785449751c8d0b2f8`
2. This will open the task details page

## Step 2: Find Public IP in Task Details

Once you're in the task details page, look for:

### Option A: Network Section
- Scroll down to the **Network** section
- Look for **Public IP** or **Public IPv4 address**
- It should show something like: `54.123.45.67`

### Option B: Network Bindings Section
- In the **Network** section, expand **Network bindings**
- The public IP should be listed there

## Step 3: If No Public IP is Shown

If you don't see a public IP, it means:

### Issue: Task is in Private Subnet
Your task is likely running in a **private subnet** without a public IP assigned.

### Solution: Enable Public IP Assignment

1. Go to your **ECS Service**
2. Click **Update**
3. Go to **Networking** section
4. Under **Auto-assign public IP**, select **ENABLED**
5. Make sure your task is in a **public subnet** (or subnet with NAT Gateway)
6. Click **Update**

### Alternative: Check Security Group

1. Go to **Task Details** → **Network** section
2. Note the **Security Group** ID
3. Go to **EC2 Console** → **Security Groups**
4. Find your security group
5. Edit **Inbound rules**:
   - Type: `Custom TCP`
   - Port: `8501`
   - Source: `0.0.0.0/0` (or your IP for security)
   - Description: `Streamlit access`

## Step 4: Access Your Application

Once you have the public IP:

```
http://<PUBLIC_IP>:8501
```

For example:
```
http://54.123.45.67:8501
```

## Troubleshooting

### If Task Shows "Unknown" Health Status

1. Check **CloudWatch Logs**:
   - Go to **Task Details** → **Logs** tab
   - Check for any errors

2. Check **Health Check**:
   - Verify your container is listening on port 8501
   - Check if health check is configured correctly

### If You Can't Access the App

1. **Check Security Group**: Ensure port 8501 is open
2. **Check Task Status**: Ensure task is "Running"
3. **Check Container Logs**: Look for startup errors
4. **Verify Port Mapping**: Ensure port 8501 is mapped correctly

## Quick Access Steps

1. **ECS Console** → Your Cluster → **Tasks** tab
2. Click on **Task ID**: `1f0060a010b24bd785449751c8d0b2f8`
3. Scroll to **Network** section
4. Copy the **Public IP**
5. Open browser: `http://<PUBLIC_IP>:8501`


