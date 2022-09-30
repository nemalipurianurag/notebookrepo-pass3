provider "google" {
  project = "modular-scout-345114"
  region  = "us-central1"
  #credentials = file("./ca-key.json")
}

provider "google-beta" {
  project = "modular-scout-345114"
  region  = "us-central1"
  #credentials = file("./ca-key.json")
}