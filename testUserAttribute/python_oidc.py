import requests
import os

from dotenv import load_dotenv

# Definition of the global variables
load_dotenv('config.env')

# Define variables    
tenantId = os.getenv('TENANTID')  # Replace with your Azure AD tenant ID
clientId = os.getenv('CLIENTID')  # Replace with your application (client) ID
clientSecret = os.getenv('CLIENTSECRET')  # Replace with a valid token obtained via OIDC flow
scope = "https://graph.microsoft.com/.default"  # Required scope for Microsoft Graph API
userIdentifier = os.getenv('USERIDENTIFIER')  # Replace with the user's UPN or Azure AD object ID

def getAccessToken(tenantId, clientId, clientSecret, scope):
    """
    Retrieve an access token from Azure Entra ID using client credentials flow.
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
            print(f"Information for user '{userIdentifier}' retrieved successfully:")
            print(response.json())
        else:
            print(f"Failed to retrieve user information. Status code: {response.status_code}")
            print(response.text)
    except requests.exceptions.RequestException as e:
        print(f"An error occurred during user information retrieval: {e}")

if __name__ == "__main__":
    # Step 1: Get the access token
    print("Retrieving access token...")
    accessToken = getAccessToken(tenantId, clientId, clientSecret, scope)

    if accessToken:
        print("Access Token retrieved successfully.")
        print(f"Access Token: {accessToken}")  # Optional: Print the token for debugging

        # Step 2: Use the access token to retrieve specified user information
        print(f"\nRetrieving information for user '{userIdentifier}'...")
        getUserInfo(accessToken, userIdentifier)
    else:
        print("Failed to retrieve access token. Please check your credentials and configuration.")
