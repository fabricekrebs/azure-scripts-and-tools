import requests
import os
from dotenv import load_dotenv
import time

# Load environment variables
load_dotenv('config.env')

# Define variables
tenantId = os.getenv('TENANTID')
clientId = os.getenv('CLIENTID')
clientSecret = os.getenv('CLIENTSECRET')
scope = "https://graph.microsoft.com/.default"
userIdentifier = os.getenv('USERIDENTIFIER')

# Validate environment variables
if not tenantId or not clientId or not clientSecret or not userIdentifier:
    print("Environment variables are missing. Check your 'config.env' file.")
    exit(1)

def getAccessToken(tenantId, clientId, clientSecret, scope):
    """
    Retrieve an access token from Azure AD using client credentials flow.
    """
    url = f"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token"
    data = {
        "grant_type": "client_credentials",
        "client_id": clientId,
        "client_secret": clientSecret,
        "scope": scope
    }

    try:
        response = requests.post(url, data=data)
        if response.status_code == 200:
            return response.json().get("access_token")
        else:
            print(f"Failed to obtain access token. Status code: {response.status_code}")
            print(response.text)
    except requests.exceptions.RequestException as e:
        print(f"An error occurred during token retrieval: {e}")
    return None

def getUserInfo(accessToken, userIdentifier):
    """
    Retrieve information for a specific user from the Microsoft Graph API.
    """
    userInfoUrl = f"https://graph.microsoft.com/v1.0/users/{userIdentifier}"
    headers = {
        "Authorization": f"Bearer {accessToken}"
    }

    try:
        response = requests.get(userInfoUrl, headers=headers)
        if response.status_code == 200:
            print(f"\nInformation for user '{userIdentifier}' retrieved successfully:")
            print(response.json())
        else:
            print(f"Failed to retrieve user information. Status code: {response.status_code}")
            print(response.text)
    except requests.exceptions.RequestException as e:
        print(f"An error occurred during user information retrieval: {e}")

def getUserGroups(accessToken, userIdentifier):
    """
    Retrieve groups the specified user belongs to from the Microsoft Graph API, handling pagination.
    """
    groupsUrl = f"https://graph.microsoft.com/v1.0/users/{userIdentifier}/memberOf"
    headers = {
        "Authorization": f"Bearer {accessToken}"
    }

    print(f"\nRetrieving groups for user '{userIdentifier}':")
    while groupsUrl:
        try:
            response = requests.get(groupsUrl, headers=headers)
            if response.status_code == 200:
                data = response.json()
                groups = data.get("value", [])
                for group in groups:
                    print(f"- {group.get('displayName')} (ID: {group.get('id')})")
                
                # Follow nextLink for pagination
                groupsUrl = data.get("@odata.nextLink")
            else:
                print(f"Failed to retrieve groups. Status code: {response.status_code}")
                print(response.text)
                break
        except requests.exceptions.RequestException as e:
            print(f"An error occurred during group retrieval: {e}")
            break

if __name__ == "__main__":
    # Step 1: Get the access token
    print("Retrieving access token...")
    accessToken = getAccessToken(tenantId, clientId, clientSecret, scope)

    if accessToken:
        print("Access Token retrieved successfully.")
        print(f"Access Token: {accessToken[:10]}... (truncated for security)")

        # Step 2: Retrieve user information
        print(f"\nRetrieving information for user '{userIdentifier}'...")
        getUserInfo(accessToken, userIdentifier)

        # Step 3: Retrieve user groups
        getUserGroups(accessToken, userIdentifier)
    else:
        print("Failed to retrieve access token. Please check your credentials and configuration.")