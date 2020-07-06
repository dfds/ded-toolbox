use octocrab::{Octocrab, Error};
use serde::{Serialize, Deserialize};

#[tokio::main]
async fn main() {
    let octo = Octocrab::builder()
        .personal_token(std::env::var("GITHUB_TOKEN").expect("No GITHUB_TOKEN environment variable was found"))
        .build().expect("Unable to build Octocrab client");

    let mut current_page = octo
        .orgs("dfds".to_owned())
        .list_repos()
        .per_page(100)
        .send()
        .await.unwrap();

    let mut prs = current_page.take_items();

    while let Ok(Some(mut new_page)) = octo.get_page(&current_page.next).await {
        prs.extend(new_page.take_items());
        current_page = new_page;
    }
    println!(":: DEPLOY KEYS ::");
    for repo in &prs {
        let keys = get_key(octo.clone(), repo.name.clone()).await.unwrap();
        if keys.len() > 0 {
            println!("{}", repo.name);
        }
        for key in &keys {
            println!("Key: {}", key.title);
            println!("Url: {}", key.url);
        }

        if keys.len() > 0 {
            println!("\n");
        }
    }

    println!(":: Repository users ::");
    for repo in &prs {
        let collabs = get_collaborators(octo.clone(), repo.name.clone()).await.unwrap();
        if collabs.len() > 0 {
            println!("{}", repo.name);
        }
        for collab in &collabs {
            println!("Username: {}", collab.login);
        }

        if collabs.len() > 0 {
            println!("\n");
        }
    }
}

async fn get_key(octo : Octocrab, repo_name : String) -> Result<Vec<Key>, Error> {
    let route = format!("/repos/dfds/{}/keys", repo_name);
    octo.get(route, None::<&()>).await
}

async fn get_collaborators(octo : Octocrab, repo_name : String) -> Result<Vec<RepoCollaborator>, Error> {
    let route = format!("/repos/dfds/{}/collaborators?affiliation=direct", repo_name);
    octo.get(route, None::<&()>).await
}

#[derive(Serialize, Deserialize)]
pub struct Key {
    pub id : i64,
    pub key : String,
    pub url : String,
    pub title : String,
    pub verified : bool,
    pub created_at : String,
    pub read_only : bool
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RepoCollaborator {
    pub login: String,
    pub id: i64,
    #[serde(rename = "node_id")]
    pub node_id: String,
    #[serde(rename = "avatar_url")]
    pub avatar_url: String,
    #[serde(rename = "gravatar_id")]
    pub gravatar_id: String,
    pub url: String,
    #[serde(rename = "html_url")]
    pub html_url: String,
    #[serde(rename = "followers_url")]
    pub followers_url: String,
    #[serde(rename = "following_url")]
    pub following_url: String,
    #[serde(rename = "gists_url")]
    pub gists_url: String,
    #[serde(rename = "starred_url")]
    pub starred_url: String,
    #[serde(rename = "subscriptions_url")]
    pub subscriptions_url: String,
    #[serde(rename = "organizations_url")]
    pub organizations_url: String,
    #[serde(rename = "repos_url")]
    pub repos_url: String,
    #[serde(rename = "events_url")]
    pub events_url: String,
    #[serde(rename = "received_events_url")]
    pub received_events_url: String,
    #[serde(rename = "type")]
    pub type_field: String,
    #[serde(rename = "site_admin")]
    pub site_admin: bool,
    pub permissions: Permissions,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Permissions {
    pub admin: bool,
    pub push: bool,
    pub pull: bool,
}
