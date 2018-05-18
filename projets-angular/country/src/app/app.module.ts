import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppComponent } from './app.component';
import { CountryCard } from './country/country.card';
import { HttpClientModule } from '@angular/common/http';
import { CountryService } from './country/country.service';

@NgModule({
  declarations: [
    AppComponent, CountryCard
  ],
  imports: [
    BrowserModule, HttpClientModule
  ],
  providers: [CountryService],
  bootstrap: [AppComponent]
})
export class AppModule { }
