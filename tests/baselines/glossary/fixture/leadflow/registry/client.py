from leadflow.config.registry import TIMEOUT_SECONDS


class RegistryClient:
    def __init__(self, session, base_url):
        self.session = session
        self.base_url = base_url

    def search(self, name, city):
        response = self.session.get(
            f"{self.base_url}/search", params={"q": name, "city": city}, timeout=TIMEOUT_SECONDS
        )
        return response.json().get("results", [])
