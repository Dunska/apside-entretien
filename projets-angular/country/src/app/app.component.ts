import { Component, OnInit } from '@angular/core';
import { Country } from './country/country';
import { CountryService } from './country/country.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html'
})
export class AppComponent implements OnInit {

  public countries: Array<Country>;

  constructor(private countryService: CountryService) {
    this.countries = [];
  }

  ngOnInit() {
    this.countryService.getAll().subscribe((result) => this.countries = result);
  }
}
