const wikiButton = document.getElementById("wiki")

wikiButton.addEventListener('click', () => {
    // Redirection vers une autre page
    window.location.href = 'http://wiki.batman.com';
    console.log("redirection vers le wiki")
});