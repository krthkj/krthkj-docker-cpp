# GitHub Secrets Setup

This document explains how to set up the required GitHub secrets for the Docker CI/CD pipeline.

## Required Secrets

### 1. DOCKERHUB_USERNAME
Your Docker Hub username.

**Value**: Your Docker Hub username (e.g., `krthkj`)

### 2. DOCKERHUB_TOKEN
A Docker Hub access token for authentication.

**Value**: Docker Hub access token (recommended over password)

## How to Create Docker Hub Access Token

1. **Log in to Docker Hub**
   - Go to https://hub.docker.com/
   - Sign in with your credentials

2. **Create Access Token**
   - Click on your profile picture in the top right
   - Select "Account Settings"
   - Go to "Security" tab
   - Click "New Access Token"

3. **Configure Token**
   - **Description**: Enter a descriptive name (e.g., "GitHub Actions CI/CD")
   - **Permissions**: Select required permissions:
     - `Read & Write` (for pushing images)
     - `Delete` (optional, for cleanup operations)
   - Click "Generate"

4. **Copy Token**
   - **Important**: Copy the token immediately as it won't be shown again
   - Store it securely

## How to Add Secrets to GitHub Repository

1. **Navigate to Repository Settings**
   - Go to your GitHub repository
   - Click on "Settings" tab

2. **Add Secrets**
   - In the left sidebar, click "Secrets and variables" → "Actions"
   - Under "Repository secrets", click "New repository secret"

3. **Add Each Secret**
   - **Name**: `DOCKERHUB_USERNAME`
   - **Secret**: Your Docker Hub username
   - Click "Add secret"

   - **Name**: `DOCKERHUB_TOKEN`
   - **Secret**: Your Docker Hub access token
   - Click "Add secret"

## Security Best Practices

- **Use Access Tokens**: Always use access tokens instead of passwords
- **Limited Permissions**: Grant only necessary permissions to tokens
- **Regular Rotation**: Rotate tokens periodically (every 90 days recommended)
- **Audit Access**: Monitor token usage and revoke unused tokens
- **Secure Storage**: Never commit secrets to version control

## Verification

After setting up the secrets, you can verify they work by:

1. Creating a test pull request
2. Checking the Actions tab for successful workflow runs
3. Verifying images are pushed to Docker Hub (for non-PR builds)

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify DOCKERHUB_USERNAME is correct
   - Check DOCKERHUB_TOKEN is valid and not expired
   - Ensure token has proper permissions

2. **Permission Denied**
   - Verify token has `Read & Write` permissions
   - Check if you have push access to the target repository

3. **Secret Not Found**
   - Ensure secrets are spelled correctly (case-sensitive)
   - Verify secrets are added to the correct repository

### Debug Steps

1. Check workflow logs for specific error messages
2. Verify secret names match exactly in workflow files
3. Test Docker Hub authentication locally first

## Additional Resources

- [Docker Hub Access Tokens Documentation](https://docs.docker.com/docker-hub/access-tokens/)
- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- [Docker Login Action Documentation](https://github.com/docker/login-action)