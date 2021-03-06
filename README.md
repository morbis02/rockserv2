Windows10 Setup Instructions

Download the following packages

https://www.fuzzem.com/downloads/bitnami-wampstack-7.4.8-0-windows-x64-installer.exe

https://www.fuzzem.com/downloads/strawberry-perl-5.16.3.1-64bit.msi

Clone or Copy this GIT repository. 

Instructions are going to be based on everything running out of C:\rockserv2

Install bitnami wampstack 7.4.8.0 with all the default options, set a root password for the mysql database (pick anything you wish)

Install Strawberry Perl 5.16.3.1-64Bit with all the default options

Open a command prompt

	Open a windows command prompt and install the following perl modules (others may be required also)
	
		cpan install MLDBM
	
		cpan install DBI
	
		cpan install DB_File
	
		cpan install DBD::mysql
		
		cpan install Lingua::Ispell
		
Open a webbrowser and navigate to http://127.0.0.1/phpmyadmin

	Enter root username and password

	Import the r2_schema_data.sql file
		
		Click Import
		
		Choose the file located at C:\rockserv2\r2_schema_data.sql
		
		Leave All Defaults selected and click "GO"
		
			This creates two databases with 2 users (ADMIN and PLAYER) one for DILLFROG and one for fuzzem

			It also creates a mysql user named rockserv with the password "password" that has all access rights on the two databases
			
Create folders userinfo and saved in each \src directory
			
You should now be able to start the server. Open a command prompt, 

	navigate to C:\rockserv2\dillfrog\src and type perl rockserv2.pl
	
	or 
	
	navigate to C:\rockserv2\fuzzem\src and type perl rockserv2.pl
	
You can then login using your favorite mud client 
		
		
		ip address is 127.0.0.1 
		
		username admin / player
		
		password is "password"
		
		once logged in there are a few commands you should know
			
			'adminnow' makes you an admin aand also lets you create objects, but you can try and figure out the commands for that :)
			
			'noadmin' turns off your admin
			
			'sserverjkill' shutsdown the server gracefully
			
			'restart' restarts the server gracefully
			

<!--
*** Thanks for checking out this README Template. If you have a suggestion that would
*** make this better, please fork the repo and create a pull request or simply open
*** an issue with the tag "enhancement".
*** Thanks again! Now go create something AMAZING! :D
***
***
***
*** To avoid retyping too much info. Do a search and replace for the following:
*** github_username, repo, twitter_handle, email
-->
<!--

https://www.fuzzem.com/downloads/bitnami-wampstack-7.4.8-0-windows-x64-installer.exe
https://www.fuzzem.com/downloads/strawberry-perl-5.16.3.1-64bit.msi

-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
<!--
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

-->


<!-- PROJECT LOGO -->
<!--
<br />
<p align="center">
  <a href="https://github.com/github_username/repo">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">YOUR_TITLE</h3>

  <p align="center">
    YOUR_SHORT_DESCRIPTION
    <br />
    <a href="https://github.com/github_username/repo"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/github_username/repo">View Demo</a>
    ·
    <a href="https://github.com/github_username/repo/issues">Report Bug</a>
    ·
    <a href="https://github.com/github_username/repo/issues">Request Feature</a>
  </p>
</p>
-->

<!-- TABLE OF CONTENTS -->
<!--
## Table of Contents

* [About the Project](#about-the-project)
  * [Built With](#built-with)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
* [Usage](#usage)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)



<!-- ABOUT THE PROJECT -->
<!--
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://example.com)

Here's a blank template to get started:
**To avoid retyping too much info. Do a search and replace with your text editor for the following:**
`github_username`, `repo`, `twitter_handle`, `email`


### Built With

* []()
* []()
* []()

-->

<!-- GETTING STARTED -->
<!--
## Getting Started

To get a local copy up and running follow these simple steps.

### Prerequisites

This is an example of how to list things you need to use the software and how to install them.
* npm
```sh
npm install npm@latest -g
```

### Installation
 
1. Clone the repo
```sh
git clone https://github.com/github_username/repo.git
```
2. Install NPM packages
```sh
npm install
```


<!-- USAGE EXAMPLES -->
<!--
## Usage

Use this space to show useful examples of how a project can be used. Additional screenshots, code examples and demos work well in this space. You may also link to more resources.

_For more examples, please refer to the [Documentation](https://example.com)_


<!-- ROADMAP -->
<!--
## Roadmap

See the [open issues](https://github.com/github_username/repo/issues) for a list of proposed features (and known issues).


<!-- CONTRIBUTING -->
<!--
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request



<!-- LICENSE -->
<!--
## License

Distributed under the MIT License. See `LICENSE` for more information.



<!-- CONTACT -->
<!--
## Contact

Your Name - [@twitter_handle](https://twitter.com/twitter_handle) - email

Project Link: [https://github.com/github_username/repo](https://github.com/github_username/repo)



<!-- ACKNOWLEDGEMENTS -->
<!--
## Acknowledgements

* []()
* []()
* []()





<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
<!--
[contributors-shield]: https://img.shields.io/github/contributors/othneildrew/Best-README-Template.svg?style=flat-square
[contributors-url]: https://github.com/othneildrew/Best-README-Template/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/othneildrew/Best-README-Template.svg?style=flat-square
[forks-url]: https://github.com/othneildrew/Best-README-Template/network/members
[stars-shield]: https://img.shields.io/github/stars/othneildrew/Best-README-Template.svg?style=flat-square
[stars-url]: https://github.com/othneildrew/Best-README-Template/stargazers
[issues-shield]: https://img.shields.io/github/issues/othneildrew/Best-README-Template.svg?style=flat-square
[issues-url]: https://github.com/othneildrew/Best-README-Template/issues
[license-shield]: https://img.shields.io/github/license/othneildrew/Best-README-Template.svg?style=flat-square
[license-url]: https://github.com/othneildrew/Best-README-Template/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=flat-square&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/othneildrew
[product-screenshot]: images/screenshot.png
-->