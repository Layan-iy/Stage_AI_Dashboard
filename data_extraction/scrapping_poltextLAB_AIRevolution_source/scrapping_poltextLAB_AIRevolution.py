import requests
from bs4 import BeautifulSoup
import re
import time
import csv # Nouvelle bibliothèque pour la gestion des fichiers CSV

# --- Configuration ---
BASE_URL = "https://airevolution.poltextlab.com/"

# Liste enrichie de mots-clés liés à l'IA et aux politiques (en ANGLAIS)
POLICY_KEYWORDS = [
    "political", "policy", "politics", "regulation", "framework", "governance",
    "government", "strategy"
]

# Pour stocker les articles pertinents
found_articles_data = []
visited_urls = set()
urls_to_visit = []

# Nom du fichier CSV de sortie
OUTPUT_CSV_FILE = "ai_policy_articles.csv" # Nom de fichier mis à jour pour refléter l'anglais

# --- Fonction pour récupérer le contenu d'une page ---
def fetch_page_content(url):
    if url in visited_urls:
        return None # Already visited

    print(f"Fetching: {url}")
    visited_urls.add(url)
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status() # Raises an HTTPError for bad responses (4xx or 5xx)
        time.sleep(1) # Pause for 1 second to be respectful to the server
        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return None

# --- Function to extract details from a single article ---
def extract_article_details(html_content, url):
    soup = BeautifulSoup(html_content, 'html.parser')

    # Extract Title
    title_element = soup.find('div', class_='post-header-intro')
    title = title_element.find('h1').get_text(strip=True) if title_element and title_element.find('h1') else "Title not found"

    # Extract Author
    author_element = soup.find('div', class_='post-author-name')
    author = author_element.find('a').get_text(strip=True).replace('by ', '') if author_element and author_element.find('a') else "Author not found"

    # Extract Publication Date
    date_element = soup.find('div', class_='post-date-read')
    publication_date = date_element.find('div').get_text(strip=True) if date_element and date_element.find('div') else "Date not found"

    # Extract full article text
    article_body = soup.find('div', class_='post-entry')
    full_text = ''
    if article_body:
        paragraphs = article_body.find_all('p')
        full_text = ' '.join([p.get_text(strip=True) for p in paragraphs])
    
    # Extract relevant sources/resources
    sources = []
    # Search for bookmarks (kg-bookmark-card)
    if article_body: # Only search for sources if article_body was found
        for bookmark_card in article_body.find_all('figure', class_='kg-bookmark-card'):
            bookmark_container = bookmark_card.find('a', class_='kg-bookmark-container')
            if bookmark_container:
                source_url = bookmark_container.get('href', 'URL not found')
                source_title_element = bookmark_container.find('div', class_='kg-bookmark-title')
                source_title = source_title_element.get_text(strip=True) if source_title_element else "Source title not found"
                source_author_element = bookmark_container.find('span', class_='kg-bookmark-author')
                source_author = source_author_element.get_text(strip=True) if source_author_element else "Source author not found"
                sources.append(f"Title: {source_title}, Author: {source_author}, URL: {source_url}")

        # Search for custom bookmarks (if different structure)
        for custom_bookmark_a in article_body.find_all('a', class_='custom-bookmark'):
            source_url = custom_bookmark_a.get('href', 'URL not found')
            source_title_element = custom_bookmark_a.find('strong')
            source_title = source_title_element.get_text(strip=True) if source_title_element else "Source title not found"
            sources.append(f"Title: {source_title}, URL: {source_url}")

    # Join all found sources into a single string for CSV
    all_sources_str = " | ".join(sources) if sources else "No sources found"

    return {
        'Title': title,
        'Author': author,
        'Publication Date': publication_date,
        'Article URL': url,
        'Full Text': full_text,
        'Sources and Resources': all_sources_str
    }

# --- Function to find article links on a page (homepage, categories, etc.) ---
def find_article_links(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    links = []

    # Regex to identify specific article URLs (must end with /)
    article_url_pattern = re.compile(r'^{}/[^/]+/$'.format(re.escape(BASE_URL.rstrip('/'))))
    
    # Strategy 1: Links within article card titles
    for card_title_h2 in soup.find_all('h2', class_='card-title'):
        link_tag = card_title_h2.find('a', href=True)
        if link_tag:
            href = link_tag.get('href')
            full_link = BASE_URL.rstrip('/') + href if href.startswith('/') else href
            if article_url_pattern.match(full_link) and full_link not in visited_urls and full_link not in urls_to_visit:
                links.append(full_link)
    
    # Strategy 2: Links within article card images
    for card_image_div in soup.find_all('div', class_='card-image'):
        link_tag = card_image_div.find('a', href=True)
        if link_tag:
            href = link_tag.get('href')
            full_link = BASE_URL.rstrip('/') + href if href.startswith('/') else href
            if article_url_pattern.match(full_link) and full_link not in visited_urls and full_link not in urls_to_visit:
                links.append(full_link)

    # Strategy 3: Discover tag/category pages or pagination
    # This part needs to be generic to explore the site
    for a_tag in soup.find_all('a', href=True):
        href = a_tag.get('href')
        if href:
            full_link = href
            if href.startswith('/'):
                full_link = BASE_URL.rstrip('/') + href
            
            # Only add links from the same domain that haven't been visited/added
            if full_link.startswith(BASE_URL) and full_link not in visited_urls and full_link not in urls_to_visit:
                # Filter out irrelevant links (files, internal anchors, etc.)
                if not any(ext in full_link for ext in ['.png', '.jpg', '.jpeg', '.gif', '.css', '.js', '.xml', '.ico', '#']):
                    # Try to target paths that could be article pages or article lists
                    if '/tag/' in full_link or '/page/' in full_link or article_url_pattern.match(full_link):
                        links.append(full_link)

    return list(set(links)) # Returns a list of unique and not-yet-planned links

# --- Function to check for keywords ---
def contains_keywords(text, keywords):
    text_lower = text.lower()
    found_kws = []
    for keyword in keywords:
        # re.escape() to handle special characters in keywords
        # \b for whole word match. Special handling for 'ia'/'ai' for flexibility.
        if re.search(r'\b' + re.escape(keyword.lower()) + r'\b', text_lower):
            found_kws.append(keyword)
    return found_kws

# --- Main scraping loop ---
def scrape_site(start_url):
    urls_to_visit.append(start_url)

    while urls_to_visit:
        current_url = urls_to_visit.pop(0) # Get the first URL from the list
        
        if current_url in visited_urls: # Check if the URL has already been visited
            continue
        
        html_content = fetch_page_content(current_url)
        if not html_content:
            continue

        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Determine if it's an article page
        is_article_page = soup.find('div', class_='post-entry')

        if is_article_page:
            # It's an article page, extract content and check for keywords
            article_details = extract_article_details(html_content, current_url)
            
            if article_details['Full Text']: # Ensure there's text to analyze
                keywords_in_article = contains_keywords(article_details['Full Text'], POLICY_KEYWORDS)
                if keywords_in_article:
                    article_details['Keywords Found'] = ", ".join(keywords_in_article)
                    found_articles_data.append(article_details)
                    print(f"  Article found with keywords: '{article_details['Title']}' ({article_details['Article URL']})")
        
        # Always look for new links to explore the site, whether it's an article or not
        new_links = find_article_links(html_content)
        for link in new_links:
            if link not in visited_urls and link not in urls_to_visit:
                urls_to_visit.append(link)

# --- Function to save data to a CSV file ---
def save_to_csv(data, filename):
    if not data:
        print("No data to save to CSV.")
        return

    # Define the order of columns
    fieldnames = [
        'Title',
        'Author',
        'Publication Date',
        'Article URL',
        'Keywords Found',
        'Sources and Resources',
        'Full Text' 
    ]
    
    # Ensure all columns exist for each row, even if empty
    for row in data:
        for field in fieldnames:
            if field not in row:
                row[field] = ""

    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames, delimiter=';') # Use ; as delimiter

        writer.writeheader() # Write column headers
        writer.writerows(data) # Write all data rows

    print(f"\nData successfully saved to {filename}")

# --- Start scraping ---
if __name__ == "__main__":
    print("Starting scraping...")
    scrape_site(BASE_URL)
    
    print("\n--- Articles found with keywords: ---")
    if found_articles_data:
        for article in found_articles_data:
            print(f"Title: {article['Title']}")
            print(f"URL   : {article['Article URL']}")
            print(f"Author: {article['Author']}")
            print(f"Date  : {article['Publication Date']}")
            print(f"Keywords found: {article['Keywords Found']}")
            print(f"Sources and Resources : {article['Sources and Resources']}")
            print("-" * 30)
        
        save_to_csv(found_articles_data, OUTPUT_CSV_FILE)
    else:
        print("No articles found with the specified keywords.")