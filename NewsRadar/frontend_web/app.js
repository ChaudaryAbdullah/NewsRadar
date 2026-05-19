document.addEventListener('DOMContentLoaded', async () => {
    const gridContainer = document.querySelector('.grid.grid-cols-1.md\\:grid-cols-12');
    if (!gridContainer) return;

    try {
        const response = await fetch('/api/v1/articles');
        const data = await response.json();
        const articles = data.articles;

        if (articles && articles.length > 0) {
            gridContainer.innerHTML = ''; // Clear existing hardcoded stuff

            // First article (Featured)
            const featured = articles[0];
            const featuredHTML = `
            <article class="md:col-span-8 group bg-surface border border-outline-variant rounded-xl overflow-hidden hover:shadow-lg transition-all duration-300 transform hover:scale-[1.005]">
                <div class="aspect-video relative overflow-hidden">
                    <img alt="${featured.title.replace(/"/g, '&quot;')}" class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105" src="${featured.urlToImage || 'https://via.placeholder.com/800x450'}">
                    <div class="absolute top-md left-md">
                        <span class="bg-primary-container text-on-primary-container font-label-sm text-label-sm px-3 py-1 rounded-full flex items-center gap-xs">
                            <span class="material-symbols-outlined text-[14px]" data-icon="auto_awesome" style="font-variation-settings: 'FILL' 1;">auto_awesome</span>
                            ${featured.source.name}
                        </span>
                    </div>
                </div>
                <div class="p-lg">
                    <div class="flex items-center gap-sm mb-sm">
                        <div class="w-6 h-6 rounded-full bg-on-surface-variant/10 flex items-center justify-center overflow-hidden">
                            <span class="material-symbols-outlined text-[16px] text-primary" data-icon="terminal">terminal</span>
                        </div>
                        <span class="font-label-sm text-label-sm text-on-surface-variant">${new Date(featured.publishedAt).toLocaleDateString()}</span>
                    </div>
                    <h3 class="font-headline-lg text-headline-lg text-on-surface mb-md leading-tight">${featured.title}</h3>
                    <p class="text-on-surface-variant line-clamp-2 mb-lg font-body-md">${featured.description || 'No description available.'}</p>
                    <div class="flex items-center justify-between">
                        <div class="flex gap-md">
                            <button class="flex items-center gap-xs text-on-surface-variant hover:text-primary transition-colors">
                                <span class="material-symbols-outlined text-[20px]" data-icon="bookmark">bookmark</span>
                            </button>
                            <button class="flex items-center gap-xs text-on-surface-variant hover:text-primary transition-colors">
                                <span class="material-symbols-outlined text-[20px]" data-icon="share">share</span>
                            </button>
                        </div>
                        <a href="${featured.url}" target="_blank" class="text-primary font-button text-button flex items-center gap-xs hover:gap-md transition-all">
                            Read Full Report <span class="material-symbols-outlined" data-icon="arrow_forward">arrow_forward</span>
                        </a>
                    </div>
                </div>
            </article>
            `;

            // Side articles (up to 3)
            const sideArticles = articles.slice(1, 4);
            let sideHTML = '<div class="md:col-span-4 flex flex-col gap-gutter">';
            for (const article of sideArticles) {
                sideHTML += `
                <article class="bg-surface border border-outline-variant rounded-xl overflow-hidden hover:shadow-md transition-all group p-md">
                    <div class="aspect-video rounded-lg overflow-hidden mb-md relative">
                        <img alt="${article.title.replace(/"/g, '&quot;')}" class="w-full h-full object-cover" src="${article.urlToImage || 'https://via.placeholder.com/400x225'}">
                        <div class="absolute bottom-xs right-xs">
                            <span class="bg-surface/90 backdrop-blur-sm text-on-surface font-label-sm text-[10px] px-2 py-0.5 rounded-full">
                                ${article.source.name}
                            </span>
                        </div>
                    </div>
                    <div class="flex items-center gap-sm mb-xs">
                        <span class="material-symbols-outlined text-[14px] text-secondary" data-icon="trending_up">trending_up</span>
                        <span class="font-label-sm text-[10px] text-on-surface-variant uppercase">News</span>
                    </div>
                    <a href="${article.url}" target="_blank">
                        <h4 class="font-headline-md text-headline-md text-on-surface mb-xs leading-snug line-clamp-2">${article.title}</h4>
                    </a>
                    <span class="font-label-sm text-[11px] text-on-surface-variant">${new Date(article.publishedAt).toLocaleDateString()}</span>
                </article>
                `;
            }
            sideHTML += '</div>';

            gridContainer.innerHTML = featuredHTML + sideHTML;
        }
    } catch (e) {
        console.error('Error fetching articles:', e);
    }
});
